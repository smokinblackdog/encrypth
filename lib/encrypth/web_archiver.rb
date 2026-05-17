require 'fileutils'
require 'tempfile'
require 'find'
require 'rubygems/package'
require 'openssl'
require 'base64'

module Encrypth
  class WebArchiver
    # Константы для фиксации смещений
    SALT_LEN = 32
    IV_LEN   = 12 # Рекомендуемая длина для GCM
    TAG_LEN  = 16

    def initialize(password)
      @password = password
    end
    
    def encrypt(files)
      # Используем блочную форму Tempfile, чтобы файл не удалился раньше времени
      temp_archive = Tempfile.new(['encrypted_archive', '.tar.enc'])
      temp_archive.binmode
      
      salt = OpenSSL::Random.random_bytes(SALT_LEN)
      key = derive_key(@password, salt)
      
      tar_temp = Tempfile.new(['archive', '.tar'])
      tar_temp.binmode
      
      begin
        create_tar(files, tar_temp.path)
        tar_temp.rewind # Важно вернуться в начало после записи
        
        cipher = OpenSSL::Cipher.new('aes-256-gcm').encrypt
        cipher.key = key
        iv = cipher.random_iv # Генерируем IV
        # Явно устанавливаем длину IV, чтобы избежать проблем с разными версиями OpenSSL
        cipher.iv_len = IV_LEN 
        cipher.iv = iv
        
        # Записываем заголовок
        temp_archive.write(salt)
        temp_archive.write(iv)
        
        # Шифруем потоком, чтобы не держать весь файл в памяти
        while chunk = tar_temp.read(16384)
          temp_archive.write(cipher.update(chunk))
        end
        temp_archive.write(cipher.final)
        
        # Тег записывается ПОСЛЕ шифрования данных в GCM
        auth_tag = cipher.auth_tag # Всегда 16 байт по умолчанию
        temp_archive.write(auth_tag)
        
        temp_archive.flush
        
        {
          path: temp_archive.path,
          size: File.size(temp_archive.path)
        }
      ensure
        tar_temp.close
        tar_temp.unlink
      end
    end
    
    def decrypt(archive_path, destination)
      File.open(archive_path, 'rb') do |file|
        salt = file.read(SALT_LEN)
        iv   = file.read(IV_LEN)
        
        # В GCM тег обычно в конце или после IV. 
        # В нашей схеме записи: Salt(32) + IV(12) + Data(?) + Tag(16)
        # Нужно вычислить размер зашифрованных данных
        ciphertext_len = File.size(archive_path) - SALT_LEN - IV_LEN - TAG_LEN
        
        key = derive_key(@password, salt)
        
        cipher = OpenSSL::Cipher.new('aes-256-gcm').decrypt
        cipher.key = key
        cipher.iv = iv
        
        # Читаем данные
        ciphertext = file.read(ciphertext_len)
        # Читаем тег (последние 16 байт)
        auth_tag = file.read(TAG_LEN)
        cipher.auth_tag = auth_tag
        
        begin
          decrypted = cipher.update(ciphertext) + cipher.final
        rescue OpenSSL::Cipher::CipherError
          raise "Invalid password or corrupted data (Auth Tag mismatch)"
        end
        
        # Используем binwrite для Windows и временный файл
        Tempfile.create(['decrypted', '.tar'], binmode: true) do |tar_temp|
          tar_temp.write(decrypted)
          tar_temp.rewind
          extract_tar(tar_temp.path, destination)
        end
      end
    end
    
    private
    
    def derive_key(password, salt)
      # 100k итераций - хорошо, SHA256 - хорошо
      OpenSSL::PKCS5.pbkdf2_hmac(password, salt, 100000, 32, 'sha256')
    end
    
    def create_tar(files, output_path)
      File.open(output_path, 'wb') do |f|
        Gem::Package::TarWriter.new(f) do |tar|
          files.each do |file_path|
            name = File.basename(file_path)
            if File.directory?(file_path)
              # Для простоты веб-сервиса шифруем только файлы, 
              # рекурсию лучше обработать заранее или ограничить
            elsif File.exist?(file_path)
              stat = File.stat(file_path)
              tar.add_file_simple(name, stat.mode, stat.size) do |io|
                File.open(file_path, 'rb') { |src| io.write(src.read) }
              end
            end
          end
        end
      end
    end
    
    def extract_tar(tar_path, destination)
      File.open(tar_path, 'rb') do |f|
        Gem::Package::TarReader.new(f) do |reader|
          reader.each do |entry|
            target = File.join(destination, entry.full_name)
            if entry.directory?
              FileUtils.mkdir_p(target)
            elsif entry.file?
              FileUtils.mkdir_p(File.dirname(target))
              # binwrite критичен для Windows!
              File.binwrite(target, entry.read)
            end
          end
        end
      end
    end
  end
end
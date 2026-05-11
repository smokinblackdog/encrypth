require 'fileutils'
require 'tempfile'
require 'find'
require 'rubygems/package'
require 'openssl'

module Encrypth
  class WebArchiver
    def initialize(password)
      @password = password
    end
    
    def encrypt(files)
      temp_archive = Tempfile.new(['encrypted_archive', '.tar.enc'])
      temp_archive.binmode
      
      # новая соль для каждого архива
      salt = OpenSSL::Random.random_bytes(32)
      key = derive_key(@password, salt)
      
      tar_temp = Tempfile.new(['archive', '.tar'])
      tar_temp.binmode
      
      begin
        create_tar(files, tar_temp.path)
        
        cipher = OpenSSL::Cipher.new('aes-256-gcm')
        cipher.encrypt
        cipher.key = key
        iv = cipher.random_iv
        cipher.iv = iv
        
        encrypted_data = File.open(tar_temp.path, 'rb') do |file|
          encrypted = ''
          while chunk = file.read(8192)
            encrypted << cipher.update(chunk)
          end
          encrypted << cipher.final
        end
        
        auth_tag = cipher.auth_tag
        
        # salt(32) + iv(12) + auth_tag(16) + encrypted_data
        temp_archive.write(salt)
        temp_archive.write(iv)
        temp_archive.write(auth_tag)
        temp_archive.write(encrypted_data)
        temp_archive.flush
        
        {
          path: temp_archive.path,
          size: File.size(temp_archive.path),
          salt: Base64.strict_encode64(salt)
        }
      ensure
        tar_temp.close
        tar_temp.unlink
      end
    end
    
    def decrypt(archive_path, destination)
      encrypted_data = File.binread(archive_path)
      
      # соль (первые 32 байта)
      salt = encrypted_data[0...32]
      iv = encrypted_data[32...44]
      auth_tag = encrypted_data[44...60]
      ciphertext = encrypted_data[60..-1]
      
      key = derive_key(@password, salt)
      
      cipher = OpenSSL::Cipher.new('aes-256-gcm')
      cipher.decrypt
      cipher.key = key
      cipher.iv = iv
      cipher.auth_tag = auth_tag
      
      decrypted = cipher.update(ciphertext) + cipher.final
      
      Tempfile.create(['decrypted', '.tar']) do |tar_temp|
        tar_temp.binmode
        tar_temp.write(decrypted)
        tar_temp.rewind
        extract_tar(tar_temp.path, destination)
      end
    end
    
    private
    
    def derive_key(password, salt)
      OpenSSL::PKCS5.pbkdf2_hmac(password, salt, 100000, 32, 'sha256')
    end
    
    def create_tar(files, output_path)
      Gem::Package::TarWriter.new(File.open(output_path, 'wb')) do |tar|
        files.each do |file|
          path = file.is_a?(Hash) ? file[:path] : file
          name = file.is_a?(Hash) ? (file[:name] || File.basename(path)) : File.basename(path)
          
          if File.directory?(path)
            add_directory_to_tar(tar, path, name)
          else
            add_file_to_tar(tar, path, name)
          end
        end
      end
    end
    
    def add_file_to_tar(tar, file_path, tar_name)
      stat = File.stat(file_path)
      tar.add_file_simple(tar_name, stat.mode, stat.size) do |io|
        File.open(file_path, 'rb') do |f|
          while chunk = f.read(8192)
            io.write(chunk)
          end
        end
      end
    end
    
    def add_directory_to_tar(tar, dir_path, tar_prefix)
      Find.find(dir_path) do |path|
        next if File.directory?(path)
        relative_path = path.sub("#{dir_path}/", "")
        tar_path = File.join(tar_prefix, relative_path)
        add_file_to_tar(tar, path, tar_path)
      end
    end
    
    def extract_tar(tar_path, destination)
      Gem::Package::TarReader.new(File.open(tar_path, 'rb')) do |reader|
        reader.each do |entry|
          target = File.join(destination, entry.full_name)
          if entry.directory?
            FileUtils.mkdir_p(target)
          else
            FileUtils.mkdir_p(File.dirname(target))
            File.write(target, entry.read)
          end
        end
      end
    end
  end
end
module Encrypth
  class WebArchiver
    SALT_LEN = 32
    IV_LEN   = 12
    TAG_LEN  = 16

    def initialize(password)
      @password = password
    end
    
    def encrypt(files)
      out_path = File.join(Dir.tmpdir, "enc_#{SecureRandom.hex(8)}.tar.enc")
      tar_path = File.join(Dir.tmpdir, "tar_#{SecureRandom.hex(8)}.tar")
      
      salt = OpenSSL::Random.random_bytes(SALT_LEN)
      key = derive_key(@password, salt)
      
      begin
        create_tar(files, tar_path)
        
        cipher = OpenSSL::Cipher.new('aes-256-gcm').encrypt
        cipher.key = key
        iv = cipher.random_iv
        cipher.iv_len = IV_LEN
        cipher.iv = iv
        
        File.open(out_path, 'wb') do |out_f|
          out_f.write(salt)
          out_f.write(iv)
          
          File.open(tar_path, 'rb') do |tar_f|
            while chunk = tar_f.read(16384)
              out_f.write(cipher.update(chunk))
            end
          end
          out_f.write(cipher.final)
          out_f.write(cipher.auth_tag)
        end
        
        { path: out_path, size: File.size(out_path) }
      ensure
        File.delete(tar_path) if File.exist?(tar_path)
      end
    end
    
    def decrypt(archive_path, destination)
      File.open(archive_path, 'rb') do |file|
        salt = file.read(SALT_LEN)
        iv   = file.read(IV_LEN)
        
        ciphertext_len = File.size(archive_path) - SALT_LEN - IV_LEN - TAG_LEN
        key = derive_key(@password, salt)
        
        cipher = OpenSSL::Cipher.new('aes-256-gcm').decrypt
        cipher.key = key
        cipher.iv = iv
        
        ciphertext = file.read(ciphertext_len)
        auth_tag = file.read(TAG_LEN)
        cipher.auth_tag = auth_tag
        
        decrypted_data = cipher.update(ciphertext) + cipher.final
        
        tar_path = File.join(Dir.tmpdir, "dec_#{SecureRandom.hex(8)}.tar")
        File.binwrite(tar_path, decrypted_data)
        
        begin
          extract_tar(tar_path, destination)
        ensure
          File.delete(tar_path) if File.exist?(tar_path)
        end
      end
    end

    private

    def derive_key(password, salt)
      OpenSSL::PKCS5.pbkdf2_hmac(password, salt, 100000, 32, 'sha256')
    end

    def create_tar(files, output_path)
      File.open(output_path, 'wb') do |f|
        Gem::Package::TarWriter.new(f) do |tar|
          files.each do |file_path|
            next unless File.exist?(file_path)
            stat = File.stat(file_path)
            tar.add_file_simple(File.basename(file_path), stat.mode, stat.size) do |io|
              File.open(file_path, 'rb') { |src| io.write(src.read) }
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
              File.binwrite(target, entry.read)
            end
          end
        end
      end
    end
  end
end
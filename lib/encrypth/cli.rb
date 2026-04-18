require "io/console"
require "base64"

module Encrypth
  class CLI
    def self.run(args)
      if args.length < 1
        puts "Использование: encrypth.rb <archive> <flag (-e/-d)> <...files/destination?>"
        exit(1)
      end

      archive = args[0]
      flag = args[1]
      
      if flag == "-e"
        if File.exist?(archive)
          puts "Архив #{archive} уже существует. Пожалуйста, выберите другое имя или удалите существующий архив."
          exit(1)
        end
        files = args[2..-1]
        encrypt_files(files, archive)
      elsif flag == "-d"
        if !File.exist?(archive)
          puts "Архив #{archive} не существует."
          exit(1)
        end
        destination = args[2]
        if destination && File.exist?(destination) && !File.directory?(destination)
          puts "Указанный путь #{destination} не является директорией."
          exit(1)
        end
        destination = "." if destination.nil? || destination.empty?
        decrypt_to_directory(archive, destination)
      else
        puts "Неверный флаг. Используйте -e для шифрования или -d для дешифрования."
        exit(1)
      end
    end

    def self.encrypt_files(files, archive)
      password = read_password("Задайте пароль: ")
      cipher_data = Encrypth::Cipher.from_password(password)
      save_salt(archive, cipher_data[:salt])
      cipher = Encrypth::Cipher.new(cipher_data[:key])
      archiver = Encrypth::Archiver.new(cipher)
      archiver.encrypt_files(files, archive)
    end

    def self.decrypt_to_directory(archive, destination)
      password = read_password("Введите пароль: ")
      salt = load_salt(archive)
      cipher_data = Encrypth::Cipher.from_password(password, salt)
      cipher = Encrypth::Cipher.new(cipher_data[:key])
      archiver = Encrypth::Archiver.new(cipher)
      archiver.decrypt_to_directory(archive, destination)
    end

    private

    def self.salt_path(archive)
      "#{archive}.salt"
    end

    def self.save_salt(archive, salt)
      File.binwrite(salt_path(archive), Base64.strict_encode64(salt))
    end

    def self.load_salt(archive)
      salt_file = salt_path(archive)
      unless File.exist?(salt_file)
        raise "Файл соли не найден. Невозможно восстановить ключ для архива #{archive}."
      end

      Base64.decode64(File.read(salt_file))
    end

    def self.read_password(prompt)
      print prompt
      $stdout.flush
      password = STDIN.noecho { |io| io.gets }&.chomp || ""
      puts
      password
    end
  end
end
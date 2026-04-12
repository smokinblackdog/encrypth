require "io/console"
require "base64"

module Encrypth
  class CLI
    def self.run(args)
      if args.length < 1
        puts "Использование: encrypth <archive>"
        exit(1)
      end

      archive = args[0]
      if !File.exist?(archive)
        files = []
        loop do
          print "Введите путь к файлу или директории (или нажмите Enter для завершения): "
          input = STDIN.gets&.chomp
          break if input.nil? || input.empty?
          files << input
        end
        encrypt_files(files, archive)
      else
        print "Введите директорию для извлечения файлов или Enter для текущей:"
        destination = STDIN.gets&.chomp
        destination = "." if destination.nil? || destination.empty?
        decrypt_to_directory(archive, destination)
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
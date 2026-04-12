require "fileutils"
require "stringio"
require "find"
require "rubygems/package"

module Encrypth
  class Archiver
    def initialize(cipher)
      @cipher = cipher
    end

    # Шифрует содержимое файлов и сохраняет его в виде зашифрованного архива
    def encrypt_files(files, archive_path)
      tar_content = create_tar_archive(files, archive_path)
      encrypted = @cipher.encrypt(tar_content)
      File.binwrite(archive_path, encrypted)
    end

    # Дешифрует архив и извлекает файлы в указанную директорию
    def decrypt_to_directory(archive_path, destination)
      encrypted = File.binread(archive_path)
      tar_content = @cipher.decrypt(encrypted)
      extract_tar_archive(tar_content, destination)
    end

    private

    # Создает tar-архив из списка файлов и возвращает его содержимое в виде строки
    def create_tar_archive(files, archive_path)
      io = StringIO.new.tap { |s| s.set_encoding("binary") }
      Gem::Package::TarWriter.new(io) do |tar|
        files.each do |file|
          if File.directory?(file)
            add_directory_to_archive(tar, file)
          else
            add_file_to_archive(tar, file)
          end
        end
      end
      io.string
    end

    def add_directory_to_archive(archive, directory)
      Find.find(directory) do |path|
        next if File.directory?(path)
        tar_path = path.sub("#{directory}/", "")
        archive.add_file(tar_path, File.stat(path).mode) do |f|
          f.write(File.binread(path))
        end
      end
    end

    def add_file_to_archive(archive, file)
      tar_path = File.basename(file)
      archive.add_file(tar_path, File.stat(file).mode) do |f|
        f.write(File.binread(file))
      end
    end

    # Извлекает файлы из tar-архива, который передается в виде строки
    def extract_tar_archive(archive_content, destination) 
      io = StringIO.new(archive_content).tap { |s| s.set_encoding("binary") }
      Gem::Package::TarReader.new(io) do |tar|
        tar.each do |entry|
          path = File.join(destination, entry.full_name)
          if entry.directory?
            FileUtils.mkdir_p(path)
          else
            FileUtils.mkdir_p(File.dirname(path))
            File.write(path, entry.read)
          end
        end
      end
    end

  end
end
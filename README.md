# Encrypth

`Encrypth` — это простой Ruby gem для безопасного архивирования и шифрования файлов с помощью AES-256-GCM. Gem был создан в качестве учебного проекта, и в дальнейшем можно ожидать расширение функционала.

## Что делает

- создает зашифрованный tar-архив из файлов и директорий
- использует надежный режим шифрования AES-256-GCM
- генерирует ключ по паролю через PBKDF2-HMAC-SHA256
- сохраняет соль отдельно в файле `archive.salt`
- извлекает и расшифровывает содержимое обратно в указанную директорию

## Установка

```sh
bundle install
```

## Использование CLI

Синтаксис:

```sh
ruby lib/encrypth.rb <archive> <-e|-d> <...files|destination>
```

### Шифрование

```sh
ruby lib/encrypth.rb secret.enc -e file1.txt folder2 file3.jpg
```

- `secret.enc` — имя выходного зашифрованного архива
- `-e` — флаг шифрования
- перечислите файлы и/или директории для архивации
- пароль вводится скрыто
- создается файл соли `secret.enc.salt`

### Дешифрование

```sh
ruby lib/encrypth.rb secret.enc -d output_folder
```

- `secret.enc` — существующий зашифрованный архив
- `-d` — флаг дешифрования
- `output_folder` — папка для извлечения файлов
- если папка не указана, используется текущая директория

## API

`Encrypth` предоставляет базовый API для шифрования и дешифрования данных:

- `Encrypth.generate_key` — создает случайный 32-байтовый ключ
- `Encrypth.from_password(password, salt = nil)` — создает ключ из пароля и соли
- `Encrypth.new(key).encrypt(data)` — шифрует строку
- `Encrypth.new(key).decrypt(encrypted_string)` — расшифровывает строку

## Структура проекта

- `lib/encrypth.rb` — точка входа
- `lib/encrypth/cli.rb` — CLI-интерфейс
- `lib/encrypth/cipher.rb` — шифрование AES-256-GCM и PBKDF2
- `lib/encrypth/archiver.rb` — создание и извлечение tar-архива
- `demo/encrypthdemo.rb` — демонстрация базового шифрования
- `test/encrypth_test.rb` — набор тестов на Minitest

## Лицензия

Проект распространяется под лицензией MIT.

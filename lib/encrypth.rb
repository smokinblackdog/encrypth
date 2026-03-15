require "openssl"
require "base64"

class Encrypth
  def initialize(key)
    @key = key
    validate_key!
  end

  # Шифрует данные и возвращает строку для хранения
  def encrypt(data)
    cipher = OpenSSL::Cipher.new("aes-256-gcm")
    cipher.encrypt
    cipher.key = @key
    
    iv = cipher.random_iv
    encrypted = cipher.update(data) + cipher.final
    auth_tag = cipher.auth_tag

    package(iv, encrypted, auth_tag)
  end

   # Дешифрует данные из строки, созданной методом encrypt
  def decrypt(string)
    iv, encrypted, auth_tag = unpack(string)
    
    cipher = OpenSSL::Cipher.new("aes-256-gcm")
    cipher.decrypt
    cipher.key = @key
    cipher.iv = iv
    cipher.auth_tag = auth_tag
    
    cipher.update(encrypted) + cipher.final
  end
  
  # Генерирует случайный ключ (32 байта)
  def self.generate_key
    SecureRandom.random_bytes(32)
  end
  
  # Создает ключ из пароля (с солью)
  def self.from_password(password, salt = nil)
    salt ||= SecureRandom.random_bytes(16)
    key = OpenSSL::PKCS5.pbkdf2_hmac(password, salt, 20000, 32, "SHA256")
    { key: key, salt: salt }
  end
  
  private
  
  def validate_key!
    if @key.bytesize != 32
      raise Error, "Ключ должен быть 32 байта (получено #{@key.bytesize})"
    end
  end
  
  def package(iv, encrypted, auth_tag)
    [
      Base64.strict_encode64(iv),
      Base64.strict_encode64(encrypted),
      Base64.strict_encode64(auth_tag)
    ].join("--")
  end
  
  def unpack(string)
    parts = string.split("--", 3)
    [
      Base64.decode64(parts[0]),
      Base64.decode64(parts[1]),
      Base64.decode64(parts[2])
    ]
  end
end
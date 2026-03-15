$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "minitest/autorun"
require "encrypth"

class TestEncrypth < Minitest::Test
  def setup
    @key = Encrypth.generate_key
    @cipher = Encrypth.new(@key)
  end
  
  def test_encrypts_and_decrypts
    original = "Hello, World!"
    encrypted = @cipher.encrypt(original)
    decrypted = @cipher.decrypt(encrypted)
    
    assert_equal original, decrypted
  end
  
  def test_different_keys_produce_different_results
    data = "test"
    key1 = Encrypth.generate_key
    key2 = Encrypth.generate_key
    
    result1 = Encrypth.new(key1).encrypt(data)
    result2 = Encrypth.new(key2).encrypt(data)
    
    refute_equal result1, result2
  end
  
  def test_from_password_generates_valid_key
    result = Encrypth.from_password("mypassword")
    key = result[:key]
    salt = result[:salt]
    
    # Тот же пароль + соль дают тот же ключ
    same_key = Encrypth.from_password("mypassword", salt)[:key]
    assert_equal key, same_key
    
    # Другой пароль даёт другой ключ
    other_key = Encrypth.from_password("other", salt)[:key]
    refute_equal key, other_key
  end
  
  def test_raises_error_on_bad_key_length
    assert_raises(Encrypth::Error) do
      Encrypth.new("too short")
    end
  end
end
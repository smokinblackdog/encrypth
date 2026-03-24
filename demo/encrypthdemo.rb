require_relative '../lib/encrypth.rb'

key = Encrypth.generate_key
cipher = Encrypth.new(key)
original = "secret"
puts original
encrypted = cipher.encrypt(original)
puts encrypted
decrypted = cipher.decrypt(encrypted)
puts decrypted

if original == decrypted then puts "succsess" else "error :(" end
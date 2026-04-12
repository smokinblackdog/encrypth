module Encrypth
  require_relative "encrypth/cipher"
  require_relative "encrypth/archiver"
  require_relative "encrypth/cli"

  CLI.run(ARGV)
end
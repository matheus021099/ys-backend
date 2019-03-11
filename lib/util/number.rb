require 'base_x'

class Util::Number
  class << self
    def encode(val)
      str = BaseX::RFC4648Base32.integer_to_string(val)
      if str.length < 5
        # str = %w(0 1 8 9 0 1 8 9 0 1 8 9).shuffle.sample(5 - str.length).join() + str
        # str = '9' * (5 - str.length) + str
        str = '10891'.slice(0, 5 - str.length) + str
      end
      str
    end

    def decode(str)
      str.gsub!(/[0189]/, '')
      BaseX::RFC4648Base32.string_to_integer(str)
    end
  end
end

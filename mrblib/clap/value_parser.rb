module Clap
  # Base class for value parsers
  class ValueParser
    def parse(value)
      value
    end

    def type_name
      "string"
    end

    def possible_values
      nil
    end
  end

  # Default string parser (passthrough)
  class StringParser < ValueParser
    def parse(value)
      value.to_s
    end

    def type_name
      "string"
    end
  end

  # Integer parser
  class IntParser < ValueParser
    def parse(value)
      Integer(value)
    rescue ArgumentError
      raise InvalidValueError.new(nil, value, "an integer")
    end

    def type_name
      "integer"
    end
  end

  # Float parser
  class FloatParser < ValueParser
    def parse(value)
      Float(value)
    rescue ArgumentError
      raise InvalidValueError.new(nil, value, "a number")
    end

    def type_name
      "number"
    end
  end

  # Boolean parser (true/false/yes/no/1/0/on/off)
  class BoolParser < ValueParser
    TRUE_VALUES = %w[true yes 1 on].freeze
    FALSE_VALUES = %w[false no 0 off].freeze

    def parse(value)
      lower = value.to_s.downcase
      return true if TRUE_VALUES.include?(lower)
      return false if FALSE_VALUES.include?(lower)
      raise InvalidValueError.new(nil, value, "a boolean (true/false/yes/no/1/0/on/off)")
    end

    def type_name
      "boolean"
    end

    def possible_values
      TRUE_VALUES + FALSE_VALUES
    end
  end

  # Path parser with optional existence check
  class PathParser < ValueParser
    def initialize(must_exist: false)
      @must_exist = must_exist
    end

    def parse(value)
      if @must_exist && !File.exist?(value)
        raise InvalidValueError.new(nil, value, "an existing path")
      end
      value
    end

    def type_name
      @must_exist ? "existing path" : "path"
    end
  end

  # Enum parser (restrict to specific values)
  class EnumParser < ValueParser
    def initialize(values, ignore_case: false)
      @values = values.map(&:to_s)
      @ignore_case = ignore_case
    end

    def parse(value)
      str = value.to_s
      check = @ignore_case ? str.downcase : str

      @values.each do |v|
        match = @ignore_case ? v.downcase : v
        return v if match == check
      end

      raise InvalidValueError.new(nil, value, "one of: #{@values.join(', ')}")
    end

    def type_name
      "value"
    end

    def possible_values
      @values
    end
  end

  # Regex parser
  class RegexParser < ValueParser
    def initialize(pattern, type_name = "value")
      @pattern = pattern
      @type_name_str = type_name
    end

    def parse(value)
      unless @pattern.match?(value)
        raise InvalidValueError.new(nil, value, "matching pattern #{@pattern.inspect}")
      end
      value
    end

    def type_name
      @type_name_str
    end
  end

  # Numeric range parser
  class RangeParser < ValueParser
    def initialize(min: nil, max: nil)
      @min = min
      @max = max
    end

    def parse(value)
      num = Integer(value)
      if @min && num < @min
        raise InvalidValueError.new(nil, value, "a number >= #{@min}")
      end
      if @max && num > @max
        raise InvalidValueError.new(nil, value, "a number <= #{@max}")
      end
      num
    rescue ArgumentError
      raise InvalidValueError.new(nil, value, "an integer")
    end

    def type_name
      if @min && @max
        "integer (#{@min}..#{@max})"
      elsif @min
        "integer (>= #{@min})"
      elsif @max
        "integer (<= #{@max})"
      else
        "integer"
      end
    end
  end

  # URL parser
  class UrlParser < ValueParser
    URL_PATTERN = /\A(https?|ftp):\/\/[^\s\/$.?#].[^\s]*\z/i

    def parse(value)
      unless URL_PATTERN.match?(value)
        raise InvalidValueError.new(nil, value, "a valid URL")
      end
      value
    end

    def type_name
      "url"
    end
  end

  # Custom parser with block
  class CustomParser < ValueParser
    def initialize(type_name = "value", &block)
      @type_name_str = type_name
      @block = block
    end

    def parse(value)
      result = @block.call(value)
      if result == false
        raise InvalidValueError.new(nil, value, @type_name_str)
      end
      result == true ? value : result
    end

    def type_name
      @type_name_str
    end
  end
end

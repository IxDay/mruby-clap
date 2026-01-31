module Clap
  # Holds a matched value with metadata
  class MatchedValue
    attr_reader :value, :source

    def initialize(value, source = ValueSource::COMMAND_LINE)
      @value = value
      @source = source
    end
  end

  # Result of parsing command-line arguments
  class ArgMatches
    attr_reader :trailing

    def initialize
      @values = {}      # id => Array of MatchedValue
      @flags = {}       # id => count (Integer)
      @subcommand = nil # { name: String, matches: ArgMatches }
      @present = {}     # id => true (for tracking presence)
      @trailing = []    # Arguments after --
    end

    # Get a single value for an argument
    def get_one(id, type = nil)
      id = id.to_s
      values = @values[id]
      return nil if values.nil? || values.empty?

      value = values.last.value
      return value if type.nil?

      convert_value(value, type)
    end

    # Get a single value, raising if not present
    def get_one!(id, type = nil)
      result = get_one(id, type)
      raise MissingRequiredError.new(id) if result.nil?
      result
    end

    # Get a single value with default
    def get_one_or(id, default)
      get_one(id) || default
    end

    # Get multiple values for an argument
    def get_many(id, type = nil)
      id = id.to_s
      values = @values[id]
      return [] if values.nil?

      results = values.map(&:value)
      return results if type.nil?

      results.map { |v| convert_value(v, type) }
    end

    # Get counter value for an argument
    def get_count(id)
      @flags[id.to_s] || 0
    end

    # Check if a flag is set (counter > 0 or SetTrue)
    def flag?(id)
      get_count(id) > 0
    end

    # Check if argument was provided (from any source)
    def contains?(id)
      @present.key?(id.to_s)
    end

    # Alias for contains?
    def present?(id)
      contains?(id)
    end

    # Get the source of a value
    def value_source(id)
      id = id.to_s
      values = @values[id]
      return nil if values.nil? || values.empty?
      values.last.source
    end

    # Get subcommand info
    def subcommand
      @subcommand
    end

    # Get subcommand name
    def subcommand_name
      @subcommand && @subcommand[:name]
    end

    # Get subcommand matches
    def subcommand_matches(name = nil)
      return nil unless @subcommand
      return @subcommand[:matches] if name.nil?
      return @subcommand[:matches] if @subcommand[:name] == name.to_s
      nil
    end

    # Get raw matched values with metadata
    def get_raw(id)
      @values[id.to_s] || []
    end

    # Iterate over all argument IDs
    def each_id(&block)
      (@values.keys + @flags.keys).uniq.each(&block)
    end

    # Get all argument IDs
    def ids
      (@values.keys + @flags.keys).uniq
    end

    # Check if no arguments were matched
    def empty?
      @values.empty? && @flags.empty? && @subcommand.nil?
    end

    # Internal: Set a value
    def set_value(id, value, source = ValueSource::COMMAND_LINE)
      id = id.to_s
      @values[id] = [MatchedValue.new(value, source)]
      @present[id] = true
    end

    # Internal: Append a value
    def append_value(id, value, source = ValueSource::COMMAND_LINE)
      id = id.to_s
      @values[id] ||= []
      @values[id] << MatchedValue.new(value, source)
      @present[id] = true
    end

    # Internal: Set multiple values at once
    def set_values(id, values, source = ValueSource::COMMAND_LINE)
      id = id.to_s
      @values[id] = values.map { |v| MatchedValue.new(v, source) }
      @present[id] = true
    end

    # Internal: Increment flag counter
    def increment_flag(id)
      id = id.to_s
      @flags[id] ||= 0
      @flags[id] += 1
      @present[id] = true
    end

    # Internal: Set flag to specific value
    def set_flag(id, value)
      id = id.to_s
      @flags[id] = value ? 1 : 0
      @present[id] = true
    end

    # Internal: Set subcommand
    def set_subcommand(name, matches)
      @subcommand = { name: name.to_s, matches: matches }
    end

    # Internal: Add trailing arguments
    def add_trailing(args)
      @trailing.concat(args)
    end

    # Internal: Mark argument as present
    def mark_present(id)
      @present[id.to_s] = true
    end

    # Internal: Check raw presence (for validation)
    def has_value?(id)
      @values.key?(id.to_s) && !@values[id.to_s].empty?
    end

    # Internal: Check if flag was set
    def has_flag?(id)
      @flags.key?(id.to_s)
    end

    private

    def convert_value(value, type)
      case type
      when :int, :integer, Integer
        Integer(value)
      when :float, Float
        Float(value)
      when :bool, :boolean
        %w[true yes 1 on].include?(value.to_s.downcase)
      else
        value
      end
    end
  end
end

module Clap
  # Argument action types
  module ArgAction
    SET = :set           # Store value (replacing previous)
    APPEND = :append     # Append to list
    SET_TRUE = :set_true # Set flag to true
    SET_FALSE = :set_false # Set flag to false
    COUNT = :count       # Increment counter
    HELP = :help         # Display help
    VERSION = :version   # Display version
  end

  # Value source tracking
  module ValueSource
    DEFAULT = :default
    ENV = :env
    COMMAND_LINE = :command_line
  end

  # Value hints for shell completion
  module ValueHint
    UNKNOWN = :unknown
    ANY_PATH = :any_path
    FILE_PATH = :file_path
    DIR_PATH = :dir_path
    EXECUTABLE_PATH = :executable_path
    COMMAND_NAME = :command_name
    USERNAME = :username
    HOSTNAME = :hostname
    URL = :url
    EMAIL_ADDRESS = :email_address
  end

  # Builder for command-line arguments
  class Arg
    attr_reader :id, :short_flag, :long_flag, :help_text, :long_help_text
    attr_reader :default_value, :default_missing_value, :env_var
    attr_reader :conflicts, :requires_list, :required_if_list, :required_unless_list
    attr_reader :groups

    # Explicit getters for attributes that have chainable setters with same name
    def get_action; @action; end
    def get_value_parser; @value_parser; end
    def get_value_hint; @value_hint; end
    def get_num_args; @num_args; end
    def get_value_delimiter; @value_delimiter; end
    def get_value_names; @value_names; end

    def initialize(id)
      @id = id.to_s
      @short_flag = nil
      @long_flag = nil
      @help_text = nil
      @long_help_text = nil
      @required = false
      @global = false
      @hidden = false
      @default_value = nil
      @default_missing_value = nil
      @env_var = nil
      @num_args = ValueRange.one
      @value_delimiter = nil
      @value_names = []
      @action = ArgAction::SET
      @value_parser = StringParser.new
      @value_hint = ValueHint::UNKNOWN
      @conflicts = []
      @requires_list = []
      @required_if_list = []
      @required_unless_list = []
      @index = nil
      @groups = []
      @allow_multiple = false
      @hide_possible_values = false
      @hide_default_value = false
    end

    # Set short flag (-c)
    def short(flag)
      @short_flag = flag.to_s[0]
      self
    end

    # Set long flag (--config)
    def long(name)
      @long_flag = name.to_s
      self
    end

    # Set help text
    def help(text)
      @help_text = text
      self
    end

    # Set long help text
    def long_help(text)
      @long_help_text = text
      self
    end

    # Set required
    def required(value = true)
      @required = value
      self
    end

    def required?
      @required
    end

    # Set global (inherited by subcommands)
    def global(value = true)
      @global = value
      self
    end

    def global?
      @global
    end

    # Set hidden from help
    def hidden(value = true)
      @hidden = value
      self
    end

    def hidden?
      @hidden
    end

    # Set default value
    def default(value)
      @default_value = value.to_s
      self
    end

    # Set default value when flag present but no value given
    def default_missing(value)
      @default_missing_value = value.to_s
      self
    end

    # Set environment variable
    def env(var)
      @env_var = var
      self
    end

    # Set number of values accepted
    def num_args(count_or_range)
      if count_or_range.is_a?(Range)
        @num_args = ValueRange.range(count_or_range.begin, count_or_range.end)
      elsif count_or_range.is_a?(ValueRange)
        @num_args = count_or_range
      else
        @num_args = ValueRange.exactly(count_or_range.to_i)
      end
      self
    end

    # Shorthand for multiple values
    def multiple_values
      @num_args = ValueRange.at_least(1)
      self
    end

    # Set value delimiter for multiple values
    def value_delimiter(delim)
      @value_delimiter = delim.to_s[0]
      self
    end

    # Set value name for help
    def value_name(name)
      @value_names = [name.to_s]
      self
    end

    # Set multiple value names
    def value_names(*names)
      @value_names = names.map(&:to_s)
      self
    end

    # Set action type
    def action(act)
      @action = act
      # Flags don't take values
      if flag_action?(act)
        @num_args = ValueRange.zero
      end
      self
    end

    # Shorthand for flag (SetTrue action)
    def flag
      action(ArgAction::SET_TRUE)
    end

    # Shorthand for counter
    def count
      action(ArgAction::COUNT)
    end

    # Shorthand for append action
    def append
      action(ArgAction::APPEND)
    end

    # Set value parser
    def value_parser(parser)
      @value_parser = parser
      self
    end

    # Shorthand for integer parser
    def int
      @value_parser = IntParser.new
      self
    end

    # Shorthand for float parser
    def float
      @value_parser = FloatParser.new
      self
    end

    # Shorthand for bool parser
    def bool
      @value_parser = BoolParser.new
      self
    end

    # Shorthand for path parser
    def path(must_exist: false)
      @value_parser = PathParser.new(must_exist: must_exist)
      self
    end

    # Shorthand for possible values (enum)
    def possible_values(*values, ignore_case: false)
      @value_parser = EnumParser.new(values, ignore_case: ignore_case)
      self
    end

    # Shorthand for regex match
    def matches(pattern, type_name = "value")
      @value_parser = RegexParser.new(pattern, type_name)
      self
    end

    # Shorthand for numeric range
    def range(min: nil, max: nil)
      @value_parser = RangeParser.new(min: min, max: max)
      self
    end

    # Custom validator
    def validate(type_name = "value", &block)
      @value_parser = CustomParser.new(type_name, &block)
      self
    end

    # Set value hint for completions
    def value_hint(hint)
      @value_hint = hint
      self
    end

    # Add conflicting arguments
    def conflicts_with(*args)
      args.each { |a| @conflicts << a.to_s }
      self
    end

    # Add required dependencies
    def requires(*args)
      args.each { |a| @requires_list << a.to_s }
      self
    end

    # Add conditional requirement
    def required_if(arg, value)
      @required_if_list << [arg.to_s, value.to_s]
      self
    end

    # Add alternative requirement
    def required_unless(*args)
      args.each { |a| @required_unless_list << a.to_s }
      self
    end

    # Get positional index
    def positional_index
      @index
    end

    # Set positional index
    def index(idx)
      @index = idx
      self
    end

    # Mark as positional (auto-index)
    def positional
      @index = -1  # Will be assigned during command build
      self
    end

    # Allow multiple occurrences
    def allow_multiple(value = true)
      @allow_multiple = value
      self
    end

    def allow_multiple?
      @allow_multiple
    end

    # Hide possible values in help
    def hide_possible_values(value = true)
      @hide_possible_values = value
      self
    end

    def hide_possible_values?
      @hide_possible_values
    end

    # Hide default value in help
    def hide_default_value(value = true)
      @hide_default_value = value
      self
    end

    def hide_default_value?
      @hide_default_value
    end

    # Add to argument group
    def group(name)
      @groups << name.to_s
      self
    end

    # Check if this is a positional argument
    def positional?
      @index != nil && @short_flag.nil? && @long_flag.nil?
    end

    # Check if this is a flag (no value)
    def flag?
      flag_action?(@action)
    end

    # Check if this takes a value
    def takes_value?
      !flag?
    end

    # Get display name for help/errors
    def display_name
      if @long_flag
        "--#{@long_flag}"
      elsif @short_flag
        "-#{@short_flag}"
      else
        "<#{@id}>"
      end
    end

    # Get list of possible values (if any)
    def possible_values_list
      @value_parser.possible_values
    end

    # Check if argument matches given name
    def matches_name?(name)
      name = name.to_s
      @id == name || @long_flag == name || @short_flag == name
    end

    # Check if argument matches given short flag
    def matches_short?(flag)
      @short_flag == flag.to_s[0]
    end

    # Check if argument matches given long flag
    def matches_long?(name)
      @long_flag == name.to_s
    end

    private

    def flag_action?(act)
      [ArgAction::SET_TRUE, ArgAction::SET_FALSE, ArgAction::COUNT,
       ArgAction::HELP, ArgAction::VERSION].include?(act)
    end
  end
end

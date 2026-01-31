module Clap
  # Base error class for all Clap errors
  class Error < StandardError
    attr_reader :kind

    def initialize(message, kind = :unknown)
      super(message)
      @kind = kind
    end
  end

  # Raised when a required argument is missing
  class MissingRequiredError < Error
    attr_reader :arg_id

    def initialize(arg_id, message = nil)
      @arg_id = arg_id
      super(message || "required argument '#{arg_id}' was not provided", :missing_required_argument)
    end
  end

  # Raised when an unknown argument is encountered
  class UnknownArgumentError < Error
    attr_reader :arg, :suggestions

    def initialize(arg, suggestions = [])
      @arg = arg
      @suggestions = suggestions
      msg = "unknown argument '#{arg}'"
      if suggestions && !suggestions.empty?
        msg += "\n\n\tDid you mean: #{suggestions.join(', ')}?"
      end
      super(msg, :unknown_argument)
    end
  end

  # Raised when conflicting arguments are provided
  class ConflictError < Error
    attr_reader :arg1, :arg2

    def initialize(arg1, arg2)
      @arg1 = arg1
      @arg2 = arg2
      super("argument '#{arg1}' cannot be used with '#{arg2}'", :argument_conflict)
    end
  end

  # Raised when an argument value is invalid
  class InvalidValueError < Error
    attr_reader :arg_id, :value, :expected

    def initialize(arg_id, value, expected = nil)
      @arg_id = arg_id
      @value = value
      @expected = expected
      msg = "invalid value '#{value}' for argument '#{arg_id}'"
      msg += ": expected #{expected}" if expected
      super(msg, :invalid_value)
    end
  end

  # Raised when too many values are provided for an argument
  class TooManyValuesError < Error
    attr_reader :arg_id, :max, :actual

    def initialize(arg_id, max, actual)
      @arg_id = arg_id
      @max = max
      @actual = actual
      super("argument '#{arg_id}' received #{actual} values but only accepts #{max}", :too_many_values)
    end
  end

  # Raised when too few values are provided for an argument
  class TooFewValuesError < Error
    attr_reader :arg_id, :min, :actual

    def initialize(arg_id, min, actual)
      @arg_id = arg_id
      @min = min
      @actual = actual
      super("argument '#{arg_id}' requires at least #{min} values but only #{actual} provided", :too_few_values)
    end
  end

  # Raised when an unknown subcommand is encountered
  class UnknownSubcommandError < Error
    attr_reader :name, :suggestions

    def initialize(name, suggestions = [])
      @name = name
      @suggestions = suggestions
      msg = "unknown subcommand '#{name}'"
      if suggestions && !suggestions.empty?
        msg += "\n\n\tDid you mean: #{suggestions.join(', ')}?"
      end
      super(msg, :invalid_subcommand)
    end
  end

  # Raised when a required subcommand is missing
  class MissingSubcommandError < Error
    def initialize(message = nil)
      super(message || "a subcommand is required but was not provided", :missing_subcommand)
    end
  end

  # Raised when a required argument group is not satisfied
  class MissingRequiredGroupError < Error
    attr_reader :group_id

    def initialize(group_id)
      @group_id = group_id
      super("one of the arguments in group '#{group_id}' is required", :missing_required_group)
    end
  end

  # Raised when a dependency requirement is not met
  class MissingDependencyError < Error
    attr_reader :arg_id, :requires

    def initialize(arg_id, requires)
      @arg_id = arg_id
      @requires = requires
      super("argument '#{arg_id}' requires '#{requires}' to also be present", :missing_dependency)
    end
  end

  # Special error for help display - not really an error
  class HelpRequested < Error
    attr_reader :help_text

    def initialize(help_text)
      @help_text = help_text
      super("help requested", :display_help)
    end
  end

  # Special error for version display - not really an error
  class VersionRequested < Error
    attr_reader :version_text

    def initialize(version_text)
      @version_text = version_text
      super("version requested", :display_version)
    end
  end

  # Error kind constants
  module ErrorKind
    INVALID_VALUE = :invalid_value
    VALUE_VALIDATION = :value_validation
    MISSING_REQUIRED_ARGUMENT = :missing_required_argument
    TOO_MANY_VALUES = :too_many_values
    TOO_FEW_VALUES = :too_few_values
    WRONG_NUMBER_OF_VALUES = :wrong_number_of_values
    INVALID_SUBCOMMAND = :invalid_subcommand
    MISSING_SUBCOMMAND = :missing_subcommand
    UNKNOWN_ARGUMENT = :unknown_argument
    ARGUMENT_CONFLICT = :argument_conflict
    MISSING_REQUIRED_GROUP = :missing_required_group
    DISPLAY_HELP = :display_help
    DISPLAY_VERSION = :display_version
  end
end

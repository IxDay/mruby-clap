module Clap
  # Groups related arguments with validation rules
  class ArgGroup
    attr_reader :id, :args, :conflicts_with, :requires

    def initialize(id)
      @id = id
      @args = []
      @required = false
      @multiple = false
      @conflicts_with = []
      @requires = []
    end

    # Add an argument to this group
    def arg(name)
      @args << name.to_s
      self
    end

    # Add multiple arguments to this group
    def args(*names)
      names.each { |name| @args << name.to_s }
      self
    end

    # Set whether at least one argument from this group is required
    def required(value = true)
      @required = value
      self
    end

    # Check if group is required
    def required?
      @required
    end

    # Set whether multiple arguments from this group can be provided
    # When false, arguments are mutually exclusive
    def multiple(value = true)
      @multiple = value
      self
    end

    # Check if multiple args are allowed
    def multiple?
      @multiple
    end

    # Check if group is mutually exclusive (only one arg allowed)
    def exclusive?
      !@multiple
    end

    # Add conflicting groups
    def conflicts_with(*groups)
      groups.each { |g| @conflicts_with << g.to_s }
      self
    end

    # Add required groups/args
    def requires(*groups)
      groups.each { |g| @requires << g.to_s }
      self
    end

    # Check if argument is in this group
    def contains?(arg_name)
      @args.include?(arg_name.to_s)
    end
  end
end

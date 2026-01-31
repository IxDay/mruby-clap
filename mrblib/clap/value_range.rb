module Clap
  # Specifies the number of values an argument accepts
  class ValueRange
    attr_reader :min, :max

    def initialize(min, max = :unset)
      @min = min
      # :unset means use min (for single-arg constructor), nil means unbounded
      @max = max == :unset ? min : max
    end

    # Check if count is within range
    def includes?(count)
      count >= @min && (@max.nil? || count <= @max)
    end

    # Check if range is unbounded (no maximum)
    def unbounded?
      @max.nil? || @max == Float::INFINITY
    end

    # Check if range accepts exactly one value
    def one?
      @min == 1 && @max == 1
    end

    # Check if range accepts zero or one value
    def optional?
      @min == 0 && @max == 1
    end

    # Check if range requires at least one value
    def required?
      @min > 0
    end

    # Check if range accepts multiple values
    def multiple?
      @max.nil? || @max > 1
    end

    def to_s
      if @min == @max
        @min.to_s
      elsif @max.nil? || @max == Float::INFINITY
        "#{@min}.."
      else
        "#{@min}..#{@max}"
      end
    end

    # Factory methods
    class << self
      # Exactly n values
      def exactly(n)
        new(n, n)
      end

      # At least n values (unbounded max)
      def at_least(n)
        new(n, nil)
      end

      # At most n values
      def at_most(n)
        new(0, n)
      end

      # Range of values
      def range(min, max)
        new(min, max)
      end

      # Single value (default for options)
      def one
        @one ||= new(1, 1)
      end

      # Zero or one value (optional)
      def optional
        @optional ||= new(0, 1)
      end

      # Any number of values
      def any
        @any ||= new(0, nil)
      end

      # Zero values (flag)
      def zero
        @zero ||= new(0, 0)
      end
    end
  end
end

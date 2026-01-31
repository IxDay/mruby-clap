module Clap
  # Parses command-line arguments according to a Command definition
  class Parser
    def initialize(command)
      @command = command
      @matches = ArgMatches.new
      @positional_index = 0
      @trailing_mode = false
      @current_arg = nil
      @pending_values = []
      @inherited_values = {}
      @inherited_flags = {}
    end

    # Parse command-line arguments
    def parse(args, inherited_values: {}, inherited_flags: {})
      @inherited_values = inherited_values
      @inherited_flags = inherited_flags

      setup_builtin_args
      apply_inherited_values
      apply_defaults
      apply_env_vars

      i = 0
      while i < args.length
        arg = args[i]

        if @trailing_mode
          @matches.add_trailing([arg])
          i += 1
          next
        end

        if arg == "--"
          flush_pending_values
          @trailing_mode = true
          i += 1
          next
        end

        if arg.start_with?("--")
          flush_pending_values
          i = process_long_arg(args, i)
        elsif arg.start_with?("-") && arg.length > 1 && !looks_like_negative_number?(arg)
          flush_pending_values
          i = process_short_arg(args, i)
        elsif @current_arg
          process_value(arg)
          i += 1
        else
          # Could be a subcommand or positional
          i = process_positional_or_subcommand(args, i)
        end
      end

      flush_pending_values
      @matches
    end

    private

    def setup_builtin_args
      # Help flag
      unless @command.has_setting?(:disable_help_flag)
        unless @command.find_arg("help")
          help_arg = Arg.new("help")
            .short("h")
            .long("help")
            .help("Print help")
            .action(ArgAction::HELP)
          @command.add_builtin_arg(help_arg)
        end
      end

      # Version flag
      if @command.version_str && !@command.has_setting?(:disable_version_flag)
        unless @command.find_arg("version")
          version_arg = Arg.new("version")
            .short("V")
            .long("version")
            .help("Print version")
            .action(ArgAction::VERSION)
          @command.add_builtin_arg(version_arg)
        end
      end
    end

    def apply_inherited_values
      @inherited_values.each do |id, values|
        values.each { |v| @matches.append_value(id, v, ValueSource::DEFAULT) }
      end
      @inherited_flags.each do |id, count|
        count.times { @matches.increment_flag(id) }
      end
    end

    def apply_defaults
      @command.all_args.each do |arg|
        next if @matches.contains?(arg.id)
        if arg.default_value
          @matches.set_value(arg.id, arg.default_value, ValueSource::DEFAULT)
        end
      end
    end

    def apply_env_vars
      @command.all_args.each do |arg|
        next unless arg.env_var
        next if @matches.contains?(arg.id) && @matches.value_source(arg.id) == ValueSource::COMMAND_LINE

        env_value = ENV[arg.env_var]
        if env_value && !env_value.empty?
          @matches.set_value(arg.id, env_value, ValueSource::ENV)
        end
      end
    end

    def process_long_arg(args, index)
      arg_str = args[index][2..-1]  # Remove --

      # Handle --arg=value form
      if arg_str.include?("=")
        name, value = arg_str.split("=", 2)
        arg_def = find_long_arg(name)
        raise_unknown_argument("--#{name}") unless arg_def

        handle_arg_action(arg_def, value)
        return index + 1
      end

      # Handle --arg form
      arg_def = find_long_arg(arg_str)
      raise_unknown_argument("--#{arg_str}") unless arg_def

      if arg_def.flag?
        handle_arg_action(arg_def, nil)
        return index + 1
      end

      # Need to get value from next argument(s)
      @current_arg = arg_def
      index + 1
    end

    def process_short_arg(args, index)
      arg_str = args[index][1..-1]  # Remove -

      # Process each character (combined short flags like -abc)
      i = 0
      while i < arg_str.length
        flag = arg_str[i]
        arg_def = find_short_arg(flag)
        raise_unknown_argument("-#{flag}") unless arg_def

        if arg_def.flag?
          handle_arg_action(arg_def, nil)
          i += 1
        else
          # This flag takes a value
          remaining = arg_str[(i + 1)..-1]
          if remaining && !remaining.empty?
            # Value is attached: -cvalue
            handle_arg_action(arg_def, remaining)
            return index + 1
          else
            # Value is in next argument
            @current_arg = arg_def
            return index + 1
          end
        end
      end

      index + 1
    end

    def process_value(value)
      @pending_values << value

      # Check if we have enough values
      if @current_arg.get_num_args.max && @pending_values.length >= @current_arg.get_num_args.max
        flush_pending_values
      end
    end

    def flush_pending_values
      return unless @current_arg

      arg = @current_arg
      values = @pending_values

      @current_arg = nil
      @pending_values = []

      if values.empty?
        # Use default_missing_value if no value provided
        if arg.default_missing_value
          values = [arg.default_missing_value]
        elsif arg.get_num_args.min > 0
          raise TooFewValuesError.new(arg.id, arg.get_num_args.min, 0)
        else
          return
        end
      end

      # Parse and validate values
      parsed_values = values.map do |v|
        begin
          arg.get_value_parser.parse(v)
        rescue InvalidValueError => e
          raise InvalidValueError.new(arg.id, v, e.expected || arg.get_value_parser.type_name)
        end
      end

      # Handle delimiter-separated values
      if arg.get_value_delimiter
        parsed_values = parsed_values.flat_map { |v| v.to_s.split(arg.get_value_delimiter) }
      end

      # Store based on action
      case arg.get_action
      when ArgAction::SET
        parsed_values.each { |v| @matches.set_value(arg.id, v) }
      when ArgAction::APPEND
        parsed_values.each { |v| @matches.append_value(arg.id, v) }
      end
    end

    def process_positional_or_subcommand(args, index)
      value = args[index]

      # Check for subcommand first
      if @command.has_subcommands?
        subcommand = @command.find_subcommand(value)
        if subcommand
          # Parse remaining args with subcommand
          remaining_args = args[(index + 1)..-1] || []

          # Collect inherited global args
          inherited_values = {}
          inherited_flags = {}
          @command.all_args.select(&:global?).each do |arg|
            if @matches.has_value?(arg.id)
              inherited_values[arg.id] = @matches.get_many(arg.id)
            end
            if @matches.has_flag?(arg.id)
              inherited_flags[arg.id] = @matches.get_count(arg.id)
            end
          end

          sub_parser = Parser.new(subcommand)
          sub_matches = sub_parser.parse(
            remaining_args,
            inherited_values: inherited_values,
            inherited_flags: inherited_flags
          )
          @matches.set_subcommand(subcommand.name, sub_matches)
          return args.length  # Consumed all args
        end
      end

      # Treat as positional argument
      positional_args = @command.positional_args
      if @positional_index < positional_args.length
        arg = positional_args[@positional_index]
        parsed_value = arg.get_value_parser.parse(value)

        if arg.get_action == ArgAction::APPEND || arg.allow_multiple?
          @matches.append_value(arg.id, parsed_value)
        else
          @matches.set_value(arg.id, parsed_value)
          @positional_index += 1
        end
        index + 1
      else
        # Unknown positional or subcommand
        if @command.has_subcommands?
          raise_unknown_subcommand(value)
        else
          raise UnknownArgumentError.new(value)
        end
      end
    end

    def handle_arg_action(arg, value)
      case arg.get_action
      when ArgAction::SET_TRUE
        @matches.set_flag(arg.id, true)
      when ArgAction::SET_FALSE
        @matches.set_flag(arg.id, false)
      when ArgAction::COUNT
        @matches.increment_flag(arg.id)
      when ArgAction::HELP
        raise HelpRequested.new(@command.help_text)
      when ArgAction::VERSION
        raise VersionRequested.new(@command.version_str)
      when ArgAction::SET, ArgAction::APPEND
        if value
          parsed = arg.get_value_parser.parse(value)
          if arg.get_action == ArgAction::APPEND
            @matches.append_value(arg.id, parsed)
          else
            @matches.set_value(arg.id, parsed)
          end
        else
          @current_arg = arg
        end
      end
    end

    def find_long_arg(name)
      # Exact match first
      arg = @command.all_args.find { |a| a.matches_long?(name) }
      return arg if arg

      # Try prefix matching if enabled
      if @command.has_setting?(:infer_long_args)
        matches = @command.all_args.select { |a| a.long_flag && a.long_flag.start_with?(name) }
        return matches.first if matches.length == 1
      end

      nil
    end

    def find_short_arg(flag)
      @command.all_args.find { |a| a.matches_short?(flag) }
    end

    def looks_like_negative_number?(str)
      return false unless @command.has_setting?(:allow_negative_numbers)
      str =~ /^-\d+(\.\d+)?$/
    end

    def raise_unknown_argument(arg)
      suggestions = find_similar_args(arg)
      raise UnknownArgumentError.new(arg, suggestions)
    end

    def raise_unknown_subcommand(name)
      suggestions = find_similar_subcommands(name)
      raise UnknownSubcommandError.new(name, suggestions)
    end

    def find_similar_args(input)
      input = input.sub(/^-+/, "")
      candidates = @command.all_args
        .map { |a| a.long_flag }
        .compact
        .select { |name| levenshtein_distance(input, name) <= 3 }
        .sort_by { |name| levenshtein_distance(input, name) }
        .first(3)
        .map { |name| "--#{name}" }
    end

    def find_similar_subcommands(input)
      @command.subcommands
        .map(&:name)
        .select { |name| levenshtein_distance(input, name) <= 3 }
        .sort_by { |name| levenshtein_distance(input, name) }
        .first(3)
    end

    def levenshtein_distance(s1, s2)
      m = s1.length
      n = s2.length
      return n if m == 0
      return m if n == 0

      d = Array.new(m + 1) { Array.new(n + 1, 0) }

      (0..m).each { |i| d[i][0] = i }
      (0..n).each { |j| d[0][j] = j }

      (1..m).each do |i|
        (1..n).each do |j|
          cost = s1[i - 1] == s2[j - 1] ? 0 : 1
          d[i][j] = [
            d[i - 1][j] + 1,      # deletion
            d[i][j - 1] + 1,      # insertion
            d[i - 1][j - 1] + cost # substitution
          ].min
        end
      end

      d[m][n]
    end
  end
end

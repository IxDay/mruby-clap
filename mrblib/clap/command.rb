module Clap
  # Application settings flags
  module AppSettings
    PROPAGATE_VERSION = :propagate_version
    SUBCOMMAND_REQUIRED = :subcommand_required
    ALLOW_EXTERNAL_SUBCOMMANDS = :allow_external_subcommands
    SUBCOMMAND_PRECEDENCE_OVER_ARG = :subcommand_precedence_over_arg
    HIDE_AUTHOR = :hide_author
    ARG_REQUIRED_ELSE_HELP = :arg_required_else_help
    DISABLE_HELP_FLAG = :disable_help_flag
    DISABLE_VERSION_FLAG = :disable_version_flag
    DISABLE_COLORED_HELP = :disable_colored_help
    DERIVE_DISPLAY_ORDER = :derive_display_order
    ALLOW_HYPHEN_VALUES = :allow_hyphen_values
    ALLOW_NEGATIVE_NUMBERS = :allow_negative_numbers
    IGNORE_ERRORS = :ignore_errors
    FLATTEN_HELP = :flatten_help
    NEXT_LINE_HELP = :next_line_help
    HIDE_POSSIBLE_VALUES = :hide_possible_values
    DONT_COLLAPSE_ARGS_IN_USAGE = :dont_collapse_args_in_usage
    INFER_LONG_ARGS = :infer_long_args
    INFER_SUBCOMMANDS = :infer_subcommands
  end

  # Builder for CLI commands and subcommands
  class Command
    attr_reader :name, :version_str, :author_str, :about_str, :long_about_str
    attr_reader :usage_str, :before_help_str, :after_help_str
    attr_reader :args, :subcommands, :groups
    attr_reader :aliases, :hidden_aliases
    attr_accessor :parent

    def initialize(name)
      @name = name.to_s
      @display_name = nil
      @version_str = nil
      @author_str = nil
      @about_str = nil
      @long_about_str = nil
      @usage_str = nil
      @before_help_str = nil
      @after_help_str = nil
      @args = []
      @builtin_args = []
      @subcommands = []
      @groups = []
      @aliases = []
      @hidden_aliases = []
      @settings = {}
      @hidden = false
      @action_handler = nil
      @parent = nil
      @positional_counter = 0
    end

    # Set display name
    def display_name(name)
      @display_name = name.to_s
      self
    end

    # Get effective display name
    def effective_name
      @display_name || @name
    end

    # Get full command path (for nested subcommands)
    def full_name
      parts = []
      cmd = self
      while cmd
        parts.unshift(cmd.effective_name)
        cmd = cmd.parent
      end
      parts.join(" ")
    end

    # Set version string
    def version(ver)
      @version_str = ver.to_s
      self
    end

    # Set author string
    def author(auth)
      @author_str = auth.to_s
      self
    end

    # Set about (short description)
    def about(text)
      @about_str = text.to_s
      self
    end

    # Set long about (detailed description)
    def long_about(text)
      @long_about_str = text.to_s
      self
    end

    # Set custom usage string
    def usage(text)
      @usage_str = text.to_s
      self
    end

    # Set before help text
    def before_help(text)
      @before_help_str = text.to_s
      self
    end

    # Set after help text
    def after_help(text)
      @after_help_str = text.to_s
      self
    end

    # Add an argument (Arg instance or block DSL)
    def arg(arg_or_id, &block)
      if arg_or_id.is_a?(Arg)
        argument = arg_or_id
      else
        argument = Arg.new(arg_or_id)
        if block_given?
          block.call(argument)
        end
      end

      # Auto-assign positional index
      if argument.positional_index == -1
        argument.instance_variable_set(:@index, @positional_counter)
        @positional_counter += 1
      end

      @args << argument
      self
    end

    # Add multiple arguments
    def args(*arguments)
      arguments.each { |a| arg(a) }
      self
    end

    # Add a subcommand (Command instance or block DSL)
    def subcommand(cmd_or_name, &block)
      if cmd_or_name.is_a?(Command)
        subcmd = cmd_or_name
      else
        subcmd = Command.new(cmd_or_name)
        if block_given?
          block.call(subcmd)
        end
      end

      subcmd.parent = self

      # Propagate version if enabled
      if has_setting?(:propagate_version) && @version_str && !subcmd.version_str
        subcmd.version(@version_str)
      end

      @subcommands << subcmd
      self
    end

    # Set action handler
    def action(&block)
      @action_handler = block
      self
    end

    # Add argument group
    def group(grp_or_id, &block)
      if grp_or_id.is_a?(ArgGroup)
        grp = grp_or_id
      else
        grp = ArgGroup.new(grp_or_id)
        if block_given?
          block.call(grp)
        end
      end
      @groups << grp
      self
    end

    # Add alias
    def alias(name)
      @aliases << name.to_s
      self
    end

    # Add multiple aliases
    def aliases(*names)
      return @aliases if names.empty?
      names.each { |n| @aliases << n.to_s }
      self
    end

    # Add hidden alias
    def hidden_alias(name)
      @hidden_aliases << name.to_s
      self
    end

    # Set a setting
    def setting(setting)
      @settings[setting] = true
      self
    end

    # Unset a setting
    def unset(setting)
      @settings.delete(setting)
      self
    end

    # Check if setting is enabled
    def has_setting?(setting)
      @settings[setting] == true
    end

    # Shorthand settings
    def subcommand_required(value = true)
      value ? setting(AppSettings::SUBCOMMAND_REQUIRED) : unset(AppSettings::SUBCOMMAND_REQUIRED)
      self
    end

    def arg_required_else_help(value = true)
      value ? setting(AppSettings::ARG_REQUIRED_ELSE_HELP) : unset(AppSettings::ARG_REQUIRED_ELSE_HELP)
      self
    end

    def disable_help_flag(value = true)
      value ? setting(AppSettings::DISABLE_HELP_FLAG) : unset(AppSettings::DISABLE_HELP_FLAG)
      self
    end

    def disable_version_flag(value = true)
      value ? setting(AppSettings::DISABLE_VERSION_FLAG) : unset(AppSettings::DISABLE_VERSION_FLAG)
      self
    end

    def infer_long_args(value = true)
      value ? setting(AppSettings::INFER_LONG_ARGS) : unset(AppSettings::INFER_LONG_ARGS)
      self
    end

    def infer_subcommands(value = true)
      value ? setting(AppSettings::INFER_SUBCOMMANDS) : unset(AppSettings::INFER_SUBCOMMANDS)
      self
    end

    # Set hidden
    def hidden(value = true)
      @hidden = value
      self
    end

    def hidden?
      @hidden
    end

    # Get all arguments including builtins
    def all_args
      @args + @builtin_args
    end

    # Find argument by ID
    def find_arg(id)
      id = id.to_s
      all_args.find { |a| a.id == id }
    end

    # Find argument by short flag
    def find_arg_by_short(flag)
      all_args.find { |a| a.matches_short?(flag) }
    end

    # Find argument by long flag
    def find_arg_by_long(name)
      all_args.find { |a| a.matches_long?(name) }
    end

    # Find subcommand by name or alias
    def find_subcommand(name)
      name = name.to_s
      @subcommands.find do |cmd|
        cmd.name == name ||
          cmd.effective_name == name ||
          cmd.aliases.include?(name) ||
          cmd.hidden_aliases.include?(name)
      end
    end

    # Get positional arguments
    def positional_args
      @args.select(&:positional?).sort_by { |a| a.positional_index || 0 }
    end

    # Get optional (non-positional) arguments
    def optional_args
      @args.reject(&:positional?)
    end

    # Check if command has subcommands
    def has_subcommands?
      !@subcommands.empty?
    end

    # Add builtin argument (internal use)
    def add_builtin_arg(arg)
      @builtin_args << arg
    end

    # Parse arguments and return matches
    def get_matches(args = ARGV)
      parser = Parser.new(self)
      matches = parser.parse(args.dup)
      validator = Validator.new(self, matches)
      validator.validate
      matches
    end

    # Parse arguments, returning nil on error
    def try_get_matches(args = ARGV)
      get_matches(args)
    rescue Error
      nil
    end

    # Parse arguments, printing errors and exiting on failure
    def get_matches_safe(args = ARGV)
      get_matches(args)
    rescue HelpRequested => e
      puts e.help_text
      exit(0)
    rescue VersionRequested => e
      puts e.version_text
      exit(0)
    rescue Error => e
      handle_error(e)
    end

    # Parse and run action handler
    def run(args = ARGV)
      matches = get_matches_safe(args)
      run_action(matches)
      matches
    rescue Error => e
      handle_error(e)
    end

    # Get help text
    def help_text
      formatter = HelpFormatter.new(self)
      formatter.format
    end

    # Get usage text
    def usage_text
      formatter = HelpFormatter.new(self)
      formatter.format_usage
    end

    # Print help and exit
    def print_help
      puts help_text
      exit(0)
    end

    # Print version and exit
    def print_version
      puts @version_str
      exit(0)
    end

    private

    def handle_error(e)
      $stderr.puts "error: #{e.message}"
      $stderr.puts
      $stderr.puts usage_text
      $stderr.puts
      $stderr.puts "For more information, try '--help'"
      exit(1)
    end

    def run_action(matches)
      # Run subcommand action if present
      if matches.subcommand
        subcmd = find_subcommand(matches.subcommand_name)
        if subcmd
          subcmd.send(:run_action, matches.subcommand_matches)
        end
      end

      # Run this command's action
      @action_handler.call(matches) if @action_handler
    end
  end
end

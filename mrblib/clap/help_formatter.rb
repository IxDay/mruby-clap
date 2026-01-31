module Clap
  # Formats help text for commands
  class HelpFormatter
    DEFAULT_TERM_WIDTH = 80
    INDENT = "    "

    def initialize(command, term_width: DEFAULT_TERM_WIDTH)
      @command = command
      @term_width = term_width
    end

    def format
      sections = []

      sections << format_header if show_header?
      sections << format_usage
      sections << format_about if @command.about_str
      sections << format_positional_args if has_positional_args?
      sections << format_options if has_options?
      sections << format_subcommands if @command.has_subcommands?
      sections << @command.after_help_str if @command.after_help_str

      sections.compact.join("\n\n")
    end

    private

    def show_header?
      @command.version_str || (@command.author_str && !@command.has_setting?(:hide_author))
    end

    def format_header
      parts = [@command.effective_name]
      parts << @command.version_str if @command.version_str
      header = parts.join(" ")

      if @command.author_str && !@command.has_setting?(:hide_author)
        header += "\n#{@command.author_str}"
      end

      header
    end

    def format_usage
      parts = ["Usage:"]
      parts << @command.full_name

      # Add options placeholder
      if has_options?
        parts << "[OPTIONS]"
      end

      # Add positional args
      @command.positional_args.each do |arg|
        if arg.required?
          parts << "<#{arg.id.upcase}>"
        else
          parts << "[#{arg.id.upcase}]"
        end
        parts << "..." if arg.allow_multiple? || arg.get_num_args.multiple?
      end

      # Add subcommand placeholder
      if @command.has_subcommands?
        if @command.has_setting?(:subcommand_required)
          parts << "<COMMAND>"
        else
          parts << "[COMMAND]"
        end
      end

      @command.usage_str || parts.join(" ")
    end

    def format_about
      @command.long_about_str || @command.about_str
    end

    def has_positional_args?
      @command.positional_args.any? { |a| !a.hidden? }
    end

    def format_positional_args
      args = @command.positional_args.reject(&:hidden?)
      return nil if args.empty?

      lines = ["Arguments:"]

      args.each do |arg|
        name = "  <#{arg.id.upcase}>"
        help = arg.help_text || ""
        lines << format_option_line(name, help, arg)
      end

      lines.join("\n")
    end

    def has_options?
      @command.all_args.any? { |a| !a.positional? && !a.hidden? }
    end

    def format_options
      args = @command.all_args.reject { |a| a.positional? || a.hidden? }
      return nil if args.empty?

      lines = ["Options:"]

      args.each do |arg|
        name = format_option_name(arg)
        help = arg.help_text || ""
        lines << format_option_line(name, help, arg)
      end

      lines.join("\n")
    end

    def format_option_name(arg)
      parts = []

      if arg.short_flag
        parts << "-#{arg.short_flag}"
      end

      if arg.long_flag
        long = "--#{arg.long_flag}"
        if arg.takes_value?
          value_name = arg.get_value_names.first || arg.id.upcase
          long += " <#{value_name}>"
        end
        parts << long
      end

      "  " + parts.join(", ")
    end

    def format_option_line(name, help, arg)
      extras = []

      # Default value
      if arg.default_value && !arg.hide_default_value?
        extras << "[default: #{arg.default_value}]"
      end

      # Possible values
      if arg.possible_values_list && !arg.hide_possible_values?
        extras << "[possible values: #{arg.possible_values_list.join(', ')}]"
      end

      # Environment variable
      if arg.env_var
        extras << "[env: #{arg.env_var}]"
      end

      full_help = help
      if extras.any?
        full_help += " " unless full_help.empty?
        full_help += extras.join(" ")
      end

      # Calculate padding for alignment
      padding = [30 - name.length, 2].max
      "#{name}#{' ' * padding}#{full_help}"
    end

    def format_subcommands
      subcmds = @command.subcommands.reject(&:hidden?)
      return nil if subcmds.empty?

      lines = ["Commands:"]

      # Calculate max name length for alignment
      max_len = subcmds.map { |c| c.effective_name.length }.max || 0

      subcmds.each do |cmd|
        name = "  #{cmd.effective_name}"
        padding = [max_len - cmd.effective_name.length + 4, 2].max
        help = cmd.about_str || ""
        lines << "#{name}#{' ' * padding}#{help}"
      end

      lines.join("\n")
    end
  end
end

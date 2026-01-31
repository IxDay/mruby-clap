module Clap
  # Validates parsed arguments against command requirements
  class Validator
    def initialize(command, matches)
      @command = command
      @matches = matches
    end

    def validate
      validate_required_args
      validate_required_groups
      validate_conflicts
      validate_requires
      validate_required_if
      validate_required_unless
      validate_value_counts
      validate_group_exclusivity
      validate_subcommand_required
    end

    private

    def validate_required_args
      @command.all_args.each do |arg|
        next unless arg.required?
        next if @matches.contains?(arg.id)
        raise MissingRequiredError.new(arg.id)
      end
    end

    def validate_required_groups
      @command.groups.each do |group|
        next unless group.required?

        has_arg = group.args.any? { |arg_id| @matches.contains?(arg_id) }
        unless has_arg
          raise MissingRequiredGroupError.new(group.id)
        end
      end
    end

    def validate_conflicts
      @command.all_args.each do |arg|
        next unless @matches.contains?(arg.id)
        next if arg.conflicts.empty?

        arg.conflicts.each do |conflict_id|
          if @matches.contains?(conflict_id)
            raise ConflictError.new(arg.id, conflict_id)
          end
        end
      end
    end

    def validate_requires
      @command.all_args.each do |arg|
        next unless @matches.contains?(arg.id)
        next if arg.requires_list.empty?

        arg.requires_list.each do |required_id|
          unless @matches.contains?(required_id)
            raise MissingDependencyError.new(arg.id, required_id)
          end
        end
      end
    end

    def validate_required_if
      @command.all_args.each do |arg|
        next if arg.required_if_list.empty?
        next if @matches.contains?(arg.id)

        arg.required_if_list.each do |condition_id, condition_value|
          if @matches.contains?(condition_id)
            actual_value = @matches.get_one(condition_id)
            if actual_value == condition_value
              raise MissingRequiredError.new(
                arg.id,
                "argument '#{arg.id}' is required when '#{condition_id}' is '#{condition_value}'"
              )
            end
          end
        end
      end
    end

    def validate_required_unless
      @command.all_args.each do |arg|
        next if arg.required_unless_list.empty?
        next if @matches.contains?(arg.id)

        # Check if any of the "unless" args are present
        any_present = arg.required_unless_list.any? { |id| @matches.contains?(id) }
        unless any_present
          raise MissingRequiredError.new(
            arg.id,
            "argument '#{arg.id}' is required unless one of [#{arg.required_unless_list.join(', ')}] is present"
          )
        end
      end
    end

    def validate_value_counts
      @command.all_args.each do |arg|
        next unless @matches.contains?(arg.id)
        next if arg.flag?

        values = @matches.get_many(arg.id)
        count = values.length

        unless arg.get_num_args.includes?(count)
          if count < arg.get_num_args.min
            raise TooFewValuesError.new(arg.id, arg.get_num_args.min, count)
          elsif arg.get_num_args.max && count > arg.get_num_args.max
            raise TooManyValuesError.new(arg.id, arg.get_num_args.max, count)
          end
        end
      end
    end

    def validate_group_exclusivity
      @command.groups.each do |group|
        next if group.multiple?

        present_args = group.args.select { |arg_id| @matches.contains?(arg_id) }
        if present_args.length > 1
          raise ConflictError.new(present_args[0], present_args[1])
        end
      end
    end

    def validate_subcommand_required
      return unless @command.has_setting?(:subcommand_required)
      return unless @command.has_subcommands?
      return if @matches.subcommand

      # Check arg_required_else_help
      if @command.has_setting?(:arg_required_else_help)
        if @matches.empty?
          raise HelpRequested.new(@command.help_text)
        end
      else
        raise MissingSubcommandError.new
      end
    end
  end
end

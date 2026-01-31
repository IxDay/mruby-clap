# mruby compiles all files in mrblib/ in alphabetical order
# so clap.rb loads first, then clap/*.rb files load after
# We just define the module and version here, everything else
# is defined in the clap/ subdirectory files

module Clap
  VERSION = "0.1.0"

  # Build a command using block DSL
  def self.build(name, &block)
    cmd = Command.new(name)
    block.call(cmd) if block_given?
    cmd
  end

  # Build and parse arguments
  def self.parse(name, args = ARGV, &block)
    cmd = build(name, &block)
    cmd.get_matches_safe(args)
  end

  # Build, parse, and run action handlers
  def self.run(name, args = ARGV, &block)
    cmd = build(name, &block)
    cmd.run(args)
  end
end

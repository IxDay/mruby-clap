# Clap module tests

assert("Clap::VERSION") do
  assert_equal "0.1.0", Clap::VERSION
end

# ValueRange tests

assert("Clap::ValueRange.exactly") do
  r = Clap::ValueRange.exactly(3)
  assert_true r.includes?(3)
  assert_false r.includes?(2)
  assert_false r.includes?(4)
end

assert("Clap::ValueRange.at_least") do
  r = Clap::ValueRange.at_least(2)
  assert_true r.includes?(2)
  assert_true r.includes?(5)
  assert_false r.includes?(1)
  assert_true r.unbounded?
end

assert("Clap::ValueRange.range") do
  r = Clap::ValueRange.range(1, 3)
  assert_true r.includes?(1)
  assert_true r.includes?(2)
  assert_true r.includes?(3)
  assert_false r.includes?(0)
  assert_false r.includes?(4)
end

assert("Clap::ValueRange.one") do
  r = Clap::ValueRange.one
  assert_true r.one?
  assert_true r.includes?(1)
  assert_false r.includes?(0)
  assert_false r.includes?(2)
end

# Value Parser tests

assert("Clap::IntParser") do
  parser = Clap::IntParser.new
  assert_equal 42, parser.parse("42")
  assert_equal(-10, parser.parse("-10"))
  assert_raise(Clap::InvalidValueError) { parser.parse("abc") }
end

assert("Clap::FloatParser") do
  parser = Clap::FloatParser.new
  assert_equal 3.14, parser.parse("3.14")
  assert_raise(Clap::InvalidValueError) { parser.parse("abc") }
end

assert("Clap::BoolParser") do
  parser = Clap::BoolParser.new
  assert_true parser.parse("true")
  assert_true parser.parse("yes")
  assert_true parser.parse("1")
  assert_true parser.parse("on")
  assert_false parser.parse("false")
  assert_false parser.parse("no")
  assert_false parser.parse("0")
  assert_false parser.parse("off")
  assert_raise(Clap::InvalidValueError) { parser.parse("maybe") }
end

assert("Clap::EnumParser") do
  parser = Clap::EnumParser.new(%w[debug info warn error])
  assert_equal "info", parser.parse("info")
  assert_raise(Clap::InvalidValueError) { parser.parse("verbose") }
end

assert("Clap::EnumParser ignore_case") do
  parser = Clap::EnumParser.new(%w[debug info], ignore_case: true)
  assert_equal "debug", parser.parse("DEBUG")
  assert_equal "info", parser.parse("INFO")
end

assert("Clap::RangeParser") do
  parser = Clap::RangeParser.new(min: 1, max: 100)
  assert_equal 50, parser.parse("50")
  assert_raise(Clap::InvalidValueError) { parser.parse("0") }
  assert_raise(Clap::InvalidValueError) { parser.parse("101") }
end

# Arg tests

assert("Clap::Arg basic") do
  arg = Clap::Arg.new("config")
    .short("c")
    .long("config")
    .help("Configuration file")
    .required

  assert_equal "config", arg.id
  assert_equal "c", arg.short_flag
  assert_equal "config", arg.long_flag
  assert_equal "Configuration file", arg.help_text
  assert_true arg.required?
  assert_false arg.positional?
end

assert("Clap::Arg flag") do
  arg = Clap::Arg.new("verbose")
    .short("v")
    .flag

  assert_true arg.flag?
  assert_false arg.takes_value?
end

assert("Clap::Arg positional") do
  arg = Clap::Arg.new("input")
    .positional
    .required

  assert_true arg.positional?
  assert_true arg.required?
end

assert("Clap::Arg value parser shortcuts") do
  int_arg = Clap::Arg.new("port").int
  assert_kind_of Clap::IntParser, int_arg.value_parser

  float_arg = Clap::Arg.new("ratio").float
  assert_kind_of Clap::FloatParser, float_arg.value_parser

  bool_arg = Clap::Arg.new("enabled").bool
  assert_kind_of Clap::BoolParser, bool_arg.value_parser
end

assert("Clap::Arg possible_values") do
  arg = Clap::Arg.new("level")
    .possible_values("debug", "info", "warn", "error")

  assert_equal %w[debug info warn error], arg.possible_values_list
end

# ArgGroup tests

assert("Clap::ArgGroup") do
  group = Clap::ArgGroup.new("output_format")
    .args("json", "yaml", "text")
    .required

  assert_equal "output_format", group.id
  assert_equal %w[json yaml text], group.args
  assert_true group.required?
  assert_true group.exclusive?
end

assert("Clap::ArgGroup multiple") do
  group = Clap::ArgGroup.new("features")
    .args("logging", "tracing", "metrics")
    .multiple

  assert_true group.multiple?
  assert_false group.exclusive?
end

# ArgMatches tests

assert("Clap::ArgMatches get_one") do
  matches = Clap::ArgMatches.new
  matches.set_value("config", "/etc/app.conf")

  assert_equal "/etc/app.conf", matches.get_one("config")
  assert_nil matches.get_one("missing")
end

assert("Clap::ArgMatches get_many") do
  matches = Clap::ArgMatches.new
  matches.append_value("files", "a.txt")
  matches.append_value("files", "b.txt")
  matches.append_value("files", "c.txt")

  assert_equal %w[a.txt b.txt c.txt], matches.get_many("files")
end

assert("Clap::ArgMatches flags") do
  matches = Clap::ArgMatches.new
  matches.increment_flag("verbose")
  matches.increment_flag("verbose")
  matches.increment_flag("verbose")

  assert_equal 3, matches.get_count("verbose")
  assert_true matches.flag?("verbose")
  assert_false matches.flag?("quiet")
end

assert("Clap::ArgMatches contains?") do
  matches = Clap::ArgMatches.new
  matches.set_value("config", "test")

  assert_true matches.contains?("config")
  assert_true matches.present?("config")
  assert_false matches.contains?("missing")
end

assert("Clap::ArgMatches subcommand") do
  sub_matches = Clap::ArgMatches.new
  sub_matches.set_value("name", "test")

  matches = Clap::ArgMatches.new
  matches.set_subcommand("init", sub_matches)

  assert_equal "init", matches.subcommand_name
  assert_equal sub_matches, matches.subcommand_matches
  assert_equal sub_matches, matches.subcommand_matches("init")
  assert_nil matches.subcommand_matches("other")
end

# Command tests

assert("Clap::Command basic") do
  cmd = Clap::Command.new("myapp")
    .version("1.0.0")
    .author("Test Author")
    .about("A test application")

  assert_equal "myapp", cmd.name
  assert_equal "1.0.0", cmd.version_str
  assert_equal "Test Author", cmd.author_str
  assert_equal "A test application", cmd.about_str
end

assert("Clap::Command with args") do
  cmd = Clap::Command.new("myapp")
    .arg(Clap::Arg.new("config").short("c").long("config"))
    .arg(Clap::Arg.new("verbose").short("v").flag)

  assert_equal 2, cmd.args.length
  assert_not_nil cmd.find_arg("config")
  assert_not_nil cmd.find_arg("verbose")
end

assert("Clap::Command with subcommands") do
  cmd = Clap::Command.new("myapp")
    .subcommand(Clap::Command.new("init").about("Initialize"))
    .subcommand(Clap::Command.new("build").about("Build"))

  assert_true cmd.has_subcommands?
  assert_equal 2, cmd.subcommands.length
  assert_not_nil cmd.find_subcommand("init")
  assert_not_nil cmd.find_subcommand("build")
end

# Parser tests

assert("Clap parser long arg with equals") do
  cmd = Clap::Command.new("test")
    .arg(Clap::Arg.new("config").long("config"))

  matches = cmd.get_matches(["--config=/etc/app.conf"])
  assert_equal "/etc/app.conf", matches.get_one("config")
end

assert("Clap parser long arg with space") do
  cmd = Clap::Command.new("test")
    .arg(Clap::Arg.new("config").long("config"))

  matches = cmd.get_matches(["--config", "/etc/app.conf"])
  assert_equal "/etc/app.conf", matches.get_one("config")
end

assert("Clap parser short arg with space") do
  cmd = Clap::Command.new("test")
    .arg(Clap::Arg.new("config").short("c"))

  matches = cmd.get_matches(["-c", "/etc/app.conf"])
  assert_equal "/etc/app.conf", matches.get_one("config")
end

assert("Clap parser short arg attached") do
  cmd = Clap::Command.new("test")
    .arg(Clap::Arg.new("config").short("c"))

  matches = cmd.get_matches(["-c/etc/app.conf"])
  assert_equal "/etc/app.conf", matches.get_one("config")
end

assert("Clap parser combined short flags") do
  cmd = Clap::Command.new("test")
    .arg(Clap::Arg.new("verbose").short("v").flag)
    .arg(Clap::Arg.new("quiet").short("q").flag)
    .arg(Clap::Arg.new("force").short("f").flag)

  matches = cmd.get_matches(["-vqf"])
  assert_true matches.flag?("verbose")
  assert_true matches.flag?("quiet")
  assert_true matches.flag?("force")
end

assert("Clap parser count flag") do
  cmd = Clap::Command.new("test")
    .arg(Clap::Arg.new("verbose").short("v").count)

  matches = cmd.get_matches(["-v", "-v", "-v"])
  assert_equal 3, matches.get_count("verbose")
end

assert("Clap parser combined count flag") do
  cmd = Clap::Command.new("test")
    .arg(Clap::Arg.new("verbose").short("v").count)

  matches = cmd.get_matches(["-vvv"])
  assert_equal 3, matches.get_count("verbose")
end

assert("Clap parser positional args") do
  cmd = Clap::Command.new("test")
    .arg(Clap::Arg.new("input").positional)
    .arg(Clap::Arg.new("output").positional)

  matches = cmd.get_matches(["input.txt", "output.txt"])
  assert_equal "input.txt", matches.get_one("input")
  assert_equal "output.txt", matches.get_one("output")
end

assert("Clap parser subcommand") do
  cmd = Clap::Command.new("test")
    .subcommand(Clap::Command.new("init")
      .arg(Clap::Arg.new("name").positional))

  matches = cmd.get_matches(["init", "myproject"])
  assert_equal "init", matches.subcommand_name
  assert_equal "myproject", matches.subcommand_matches.get_one("name")
end

assert("Clap parser trailing args") do
  cmd = Clap::Command.new("test")
    .arg(Clap::Arg.new("verbose").short("v").flag)

  matches = cmd.get_matches(["-v", "--", "-a", "-b", "-c"])
  assert_true matches.flag?("verbose")
  assert_equal %w[-a -b -c], matches.trailing
end

assert("Clap parser default value") do
  cmd = Clap::Command.new("test")
    .arg(Clap::Arg.new("config").long("config").default("default.conf"))

  matches = cmd.get_matches([])
  assert_equal "default.conf", matches.get_one("config")
end

assert("Clap parser append action") do
  cmd = Clap::Command.new("test")
    .arg(Clap::Arg.new("include").short("I").append)

  matches = cmd.get_matches(["-I", "path1", "-I", "path2", "-I", "path3"])
  assert_equal %w[path1 path2 path3], matches.get_many("include")
end

# Validation tests

assert("Clap validator required arg") do
  cmd = Clap::Command.new("test")
    .arg(Clap::Arg.new("config").long("config").required)

  assert_raise(Clap::MissingRequiredError) do
    cmd.get_matches([])
  end
end

assert("Clap validator conflict") do
  cmd = Clap::Command.new("test")
    .arg(Clap::Arg.new("verbose").short("v").flag)
    .arg(Clap::Arg.new("quiet").short("q").flag.conflicts_with("verbose"))

  assert_raise(Clap::ConflictError) do
    cmd.get_matches(["-v", "-q"])
  end
end

assert("Clap validator requires") do
  cmd = Clap::Command.new("test")
    .arg(Clap::Arg.new("output").short("o"))
    .arg(Clap::Arg.new("format").short("f").requires("output"))

  assert_raise(Clap::MissingDependencyError) do
    cmd.get_matches(["-f", "json"])
  end
end

assert("Clap validator unknown argument") do
  cmd = Clap::Command.new("test")

  assert_raise(Clap::UnknownArgumentError) do
    cmd.get_matches(["--unknown"])
  end
end

# Help formatter tests

assert("Clap help text generation") do
  cmd = Clap::Command.new("myapp")
    .version("1.0.0")
    .about("A test application")
    .arg(Clap::Arg.new("config").short("c").long("config").help("Config file"))
    .arg(Clap::Arg.new("verbose").short("v").flag.help("Enable verbose"))

  help = cmd.help_text
  assert_include help, "myapp"
  assert_include help, "1.0.0"
  assert_include help, "A test application"
  assert_include help, "-c, --config"
  assert_include help, "Config file"
  assert_include help, "-v"
  assert_include help, "Enable verbose"
end

# DSL tests

assert("Clap.build DSL") do
  cmd = Clap.build("myapp") do |c|
    c.version "1.0.0"
    c.about "Test app"
    c.arg "config" do |a|
      a.short "c"
      a.long "config"
      a.required
    end
  end

  assert_equal "myapp", cmd.name
  assert_equal "1.0.0", cmd.version_str
  assert_not_nil cmd.find_arg("config")
  assert_true cmd.find_arg("config").required?
end

assert("Clap.build with subcommands DSL") do
  cmd = Clap.build("myapp") do |c|
    c.version "1.0.0"
    c.subcommand "init" do |sub|
      sub.about "Initialize project"
      sub.arg "name" do |a|
        a.positional
        a.required
      end
    end
  end

  assert_true cmd.has_subcommands?
  sub = cmd.find_subcommand("init")
  assert_not_nil sub
  assert_equal "Initialize project", sub.about_str
end

# Error message tests

assert("Clap error suggestions") do
  cmd = Clap::Command.new("test")
    .arg(Clap::Arg.new("config").long("config"))
    .arg(Clap::Arg.new("verbose").long("verbose"))

  begin
    cmd.get_matches(["--confg"])
    assert_true false, "Should have raised"
  rescue Clap::UnknownArgumentError => e
    assert_include e.message, "config"
  end
end

# Integration tests

assert("Clap full integration test") do
  cmd = Clap.build("myapp") do |c|
    c.version "2.0.0"
    c.author "Test Author"
    c.about "My CLI application"

    c.arg "config" do |a|
      a.short "c"
      a.long "config"
      a.help "Path to config file"
      a.default "config.yml"
    end

    c.arg "verbose" do |a|
      a.short "v"
      a.count
      a.help "Verbosity level"
    end

    c.arg "output" do |a|
      a.short "o"
      a.long "output"
      a.help "Output format"
      a.possible_values "json", "yaml", "text"
    end

    c.subcommand "run" do |sub|
      sub.about "Run the application"
      sub.arg "target" do |a|
        a.positional
        a.required
        a.help "Target to run"
      end
    end
  end

  # Test basic args
  matches = cmd.get_matches(["-c", "app.yml", "-vvv", "-o", "json"])
  assert_equal "app.yml", matches.get_one("config")
  assert_equal 3, matches.get_count("verbose")
  assert_equal "json", matches.get_one("output")

  # Test subcommand
  matches = cmd.get_matches(["run", "mytarget"])
  assert_equal "run", matches.subcommand_name
  assert_equal "mytarget", matches.subcommand_matches.get_one("target")

  # Test default value
  matches = cmd.get_matches([])
  assert_equal "config.yml", matches.get_one("config")
end

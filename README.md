# mruby-clap

A command-line argument parser for mruby, inspired by Rust's [clap](https://github.com/clap-rs/clap) library.

## Installation

Add to your `build_config.rb`:

```ruby
MRuby::Build.new do |conf|
  conf.gem github: 'IxDay/mruby-clap'
end
```

## Usage

```ruby
Clap.run("greet") do |c|
  c.version "1.0.0"
  c.about "A friendly greeter"

  c.arg "name" do |a|
    a.positional
    a.required
    a.help "Name to greet"
  end

  c.arg "count" do |a|
    a.short "n"
    a.long "count"
    a.help "Number of times to greet"
    a.default "1"
    a.int
  end

  c.arg "loud" do |a|
    a.short "l"
    a.long "loud"
    a.flag
    a.help "Greet loudly"
  end

  c.action do |matches|
    name = matches.get_one("name")
    count = matches.get_one("count")
    loud = matches.flag?("loud")

    count.times do
      greeting = "Hello, #{name}!"
      puts loud ? greeting.upcase : greeting
    end
  end
end
```

```
$ greet World -n 3 --loud
HELLO, WORLD!
HELLO, WORLD!
HELLO, WORLD!
```

## Features

- Fluent DSL for building CLI applications
- Short (`-v`) and long (`--verbose`) flags
- Positional arguments
- Subcommands with nested arguments
- Value parsers: `int`, `float`, `bool`, `possible_values`, `range`, `path`, `matches`
- Validation: `required`, `conflicts_with`, `requires`
- Flag counting (`-vvv`)
- Default values and environment variable fallbacks
- Auto-generated help text

## License

MIT

MRuby::Gem::Specification.new('mruby-clap') do |spec|
  spec.license = 'MIT'
  spec.author  = 'mruby developers'
  spec.summary = 'Command line argument parser inspired by Rust clap'

  spec.add_dependency 'mruby-array-ext',  core: 'mruby-array-ext'
  spec.add_dependency 'mruby-hash-ext',   core: 'mruby-hash-ext'
  spec.add_dependency 'mruby-string-ext', core: 'mruby-string-ext'
  spec.add_dependency 'mruby-exit',       core: 'mruby-exit'
  spec.add_dependency 'mruby-env'
end

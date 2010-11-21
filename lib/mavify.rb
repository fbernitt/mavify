
Capistrano::Configuration.instance(:must_exist).load do
  require 'scm'
  require 'recipes/build/build'
  require 'recipes/build/artifact'
  require 'patches/scm'
  
  #foo = Capistrano::Mavify::SCM.new(variables[:scm], self)
  artifacts_builder
end


Capistrano::Configuration.instance(:must_exist).load do
  require 'scm'
  require 'recipes/build/build'

  foo = Capistrano::Mavify::SCM.new(variables[:scm], self)
  
end

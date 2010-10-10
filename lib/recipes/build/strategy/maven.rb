require 'benchmark'
require 'recipes/build/strategy/base'

module Capistrano
  module Mavify
    module Build
      module Strategy

        # This class defines the abstract interface for all Mavify
        # build strategies. Subclasses must implement at least the
        # #build! method.
        class Maven < Base
          # Instantiates a strategy with a reference to the given configuration.
          def initialize(config={})
            super(config)

            # Sets the default command name for maven on your *local* machine.
            # Users may override this by setting the :build_command variable.
            default_command "mvn install -Pall"
          end


          # Executes the necessary commands to build the revision of the source
          # code identified by the +revision+ variable.
          def build!
            build_dir = variable(:build_dir)
            #raise NotImplementedError, "`build!' is not implemented by #{self.class.name}"
            puts "here we are! build_dir=[#{build_dir}] and build_repository=[#{build_repository}]"
            cmd = "cd #{build_repository} && #{command}"
            
            system(cmd)
          end
        
        
          private
        
          def command
            # For backwards compatibility with 1.x version of this module
            variable(:maven) || super
          end

        end
      end
    end
  end
end
require 'benchmark'
require 'capistrano/recipes/deploy/dependencies'

module Capistrano
  module Mavify
    module Build
      module Strategy

        # This class defines the abstract interface for all Mavify
        # build strategies. Subclasses must implement at least the
        # #build! method.
        class Base
            # If no parameters are given, it returns the current configured
            # name of the command-line utility of maven. If a parameter is
            # given, the defeault command is set to that value.
            def default_command(value=nil)
              if value
                @default_command = value
              else
                @default_command
              end
            end
           
          attr_reader :configuration

          # Instantiates a strategy with a reference to the given configuration.
          def initialize(config={})
            @configuration = config
          end

          # Executes the necessary commands to build the revision of the source
          # code identified by the +revision+ variable.
          def build!
            raise NotImplementedError, "`build!' is not implemented by #{self.class.name}"
          end

          protected

          # Returns the name of the command-line utility for this build strategy. It first
          # looks at the :build_command variable, and if it does not exist, it
          # then falls back to whatever was defined by +default_command+.
          #
          # If build_command is set to :default, the default_command will be
          # returned.
          def command
            command = variable(:build_command)
            command = nil if command == :default
            command || default_command
          end

          def build_repository
            variable(:build_repository)
          end
          
          # logs the command then executes it locally.
          # returns the command output as a string
          def run_build(cmd)
            output_on_stdout = ""
            logger.trace "executing locally: #{cmd.inspect}" if logger
            elapsed = Benchmark.realtime do
              output_on_stdout = `#{cmd}`
            end
            if $?.to_i > 0 # $? is command exit code (posix style)
              raise Capistrano::LocalArgumentError, "Command #{cmd} returned status code #{$?}"
            end
            logger.trace "command finished in #{(elapsed * 1000).round}ms" if logger
            output_on_stdout
          end
          
          # A reference to a Logger instance that the SCM can use to log
          # activity.
          def logger
            @logger ||= variable(:logger) || Capistrano::Logger.new(:output => STDOUT)
          end
          

          # A helper for accessing variable values, which takes into
          # consideration the current mode ("normal" vs. "local").
          def variable(name)
            configuration[name]
          end
        end
      end
    end
  end
end

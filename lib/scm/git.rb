module Capistrano
  module Mavify
    module SCM
      
      class Git
        # The options available for this SCM instance to reference. Should be
        # treated like a hash.
        attr_reader :configuration

        # Creates a new SCM instance with the given configuration options.
        def initialize(configuration={})
          @configuration = configuration
        end  
      end
      
    end
  end
end
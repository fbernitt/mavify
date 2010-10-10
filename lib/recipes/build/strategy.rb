module Capistrano
  module Mavify
    module Build
      module Strategy
        def self.new(strategy, config={})
          strategy_file = "recipes/build/strategy/#{strategy}"
          puts "requiring #{strategy_file}"
          require(strategy_file)

          strategy_const = strategy.to_s.capitalize.gsub(/_(.)/) { $1.upcase }
          if const_defined?(strategy_const)
            const_get(strategy_const).new(config)
          else
            raise Capistrano::Error, "could not find `#{name}::#{strategy_const}' in `#{strategy_file}'"
          end
        rescue LoadError => error
          puts error
          raise Capistrano::Error, "could not find any build strategy named `#{strategy}'"
        end
      end
    end
  end
end
module Capistrano
  module Deploy
    module SCM
   
      class Base
        def revision_name
          raise NotImplementedError, "`revision_name' is not implemented by #{self.class.name}"
        end
      end
      
      class Git < Base
        def revision_name_foo
          cmd = "git describe $(git rev-list --tags --max-count=1 #{head})"
          result = yield(cmd)
          result.trim
        end
      end
    end
  end
end
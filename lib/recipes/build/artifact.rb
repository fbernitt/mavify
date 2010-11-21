require 'set'

module Capistrano
  module Mavify
    module Build
      module Artifact

        class BuildArtifact
          attr_reader :release_dir, :globs
                    
          def initialize(release_dir, *globs)
            @release_dir = release_dir
            @globs = globs
          end
          
          def eql?(other)
            @release_dir.eql?(other.release_dir)
          end
          
          def hash
            @release_dir.hash
          end
        end
        
        class ArtifactsBuilder
          def initialize
            @artifacts = [].to_set
          end
          
          def collect(release_dir, *globs)
            @artifacts = BuildArtifact.new(release_dir, globs)
            self
          end
        end
        
        class ArtifactsCollector
          
          def initialize (target_dir, artifacts)
            @target_dir = target_dir
            @artifacts = artifacts
          end
        end
      end
    end
  end
end

def artifacts_builder
  Capistrano::Mavify::Build::Artifact::ArtifactsBuilder.new
end
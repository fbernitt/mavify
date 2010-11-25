require 'set'
require 'fileutils'

module Capistrano
  module Mavify
    module Build
      module Artifact

        class BuildArtifact
          attr_reader :build_result_dir, :filterRegExps
                    
          def initialize(build_result_dir, *filterRegExps)
            @build_result_dir = build_result_dir
            @filterRegExps = filterRegExps
          end
          
          def eql?(other)
            @build_result_dir.eql?(other.build_result_dir)
          end
          
          def hash
            @build_result_dir.hash
          end
          
          # iterates over all files within this build artifact
          def foreach
            find_files.each do |file|
              yield(@build_result_dir, file)
            end
          end
          
          # returns an array containing all files of this artifact
          def find_files
            find_files_recursive(@build_result_dir, '')
          end
          
          # recursive part of the foreach method.
          def find_files_recursive (base_directory, relative_path)
            result = []
            directory = File.join(base_directory, relative_path)
            Dir.foreach(directory) do |file|
              relative_file = relative_path.empty? ? file : File.join(relative_path, file)
              if matchesFilters(file, relative_file)
                full_path = File.join(base_directory, relative_file)
                if File.directory?(full_path)
                  result = result + find_files_recursive(base_directory, relative_file)
                else
                  result << relative_file
                end
              end
            end
            result
          end
          
          def matchesFilters (file, relative_file)
            if file == '.' || file == '..'
              return false
            end
            result = true
            @filterRegExps.each do |regexp_filter|
              result = result && !relative_file.match(regexp_filter)
            end
            result
          end
        end
        
        class ArtifactsBuilder
          def initialize
            @artifacts = [].to_set
          end
          
          def collect(build_result_dir, *filterRegExps)
            @artifacts.add(BuildArtifact.new(build_result_dir, *filterRegExps))
            self
          end
          
          def to_set
            Set.new(@artifacts)
          end
        end
        
        class ArtifactCopier
          
          def initialize (target_dir, artifact)
            @target_dir = target_dir
            @artifact = artifact
          end
          
          def copy
            @artifact.foreach do |build_dir, file|
              src_file = File.join(build_dir, file)
              target_file = File.join(@target_dir, file)
              ensure_parent_dir_exists(target_file)
              FileUtils.copy(src_file, target_file)
              #puts "Would copy #{src_file} to #{target_file} for file #{file}"
            end
          end
          
          def ensure_parent_dir_exists (target_path)
            parent = File.dirname(target_path)
            if not File.exists?(parent)
              FileUtils.mkdir_p(parent)
            end
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

def artifact_copier (target_dir, artifact)
  Capistrano::Mavify::Build::Artifact::ArtifactCopier.new(target_dir, artifact)
end

# Creattes a BuildArtifact for standard maven target folders
def maven_auto_artifact (module_name)
  builder = artifacts_builder
  builder.collect(File.join(build_repository, module_name, "target"), /classes/, /test-classes/, /maven-archiver/)
  builder.to_set
end

def maven_auto_artifacts (*module_names)
  builder = artifacts_builder
  module_names.each do |module_name|
    builder.collect(File.join(build_repository, module_name, "target"), /classes/, /test-classes/, /maven-archiver/, /.*-SNAPSHOT$/)
  end
  builder.to_set
end

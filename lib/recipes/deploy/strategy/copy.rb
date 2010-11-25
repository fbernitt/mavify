require 'recipes/deploy/strategy/base'
require 'fileutils'
require 'tempfile'  # Dir.tmpdir

module Capistrano
  module Mavify
    module Deploy
      module Strategy
        
        class Copy < Base
          def deploy!
            logger.trace "compressing target files to #{filename}"
            #Dir.chdir(build_dir) { system(compress(File.basename(destination), File.basename(filename)).join(" ")) }
            logger.info "Build dir is #{build_target_dir}"
            logger.info compress("*", File.basename(filename)).join(" ")
            Dir.chdir(build_target_dir) { system(compress("*", File.basename(filename)).join(" ")) }
          end
          
          # Returns the name of the file that the source code will be
          # compressed to.
          def filename
            @filename ||= File.join(build_dir, "#{revision_name}.#{compression.extension}")
          end
          
          def build_dir
            @build_dir ||= configuration[:build_dir] || Dir.tmpdir
          end
          
          # A struct for representing the specifics of a compression type.
          # Commands are arrays, where the first element is the utility to be
          # used to perform the compression or decompression.
          Compression = Struct.new(:extension, :compress_command, :decompress_command)
          
          # The compression method to use, defaults to :gzip.
          def compression
            remote_tar = configuration[:copy_remote_tar] || 'tar'
            local_tar = configuration[:copy_local_tar] || 'tar'
            
            type = configuration[:copy_compression] || :gzip
            case type
            when :gzip, :gz   then Compression.new("tar.gz",  [local_tar, 'czf'], [remote_tar, 'xzf'])
            when :bzip2, :bz2 then Compression.new("tar.bz2", [local_tar, 'cjf'], [remote_tar, 'xjf'])
            when :zip         then Compression.new("zip",     %w(zip -qr), %w(unzip -q))
            else raise ArgumentError, "invalid compression type #{type.inspect}"
            end
          end
          
          # Returns the command necessary to compress the given directory
          # into the given file.
          def compress(directory, file)
            compression.compress_command + [file, directory]
          end

          # Returns the command necessary to decompress the given file,
          # relative to the current working directory. It must also
          # preserve the directory structure in the file.
          def decompress(file)
            compression.decompress_command + [file]
          end
          
        end
        
      end
    end
  end
end
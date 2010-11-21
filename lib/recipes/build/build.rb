Capistrano::Configuration.instance(:must_exist).load do
require 'benchmark'
require 'capistrano/configuration/variables'
require 'capistrano/recipes/deploy/scm'
require 'capistrano/recipes/deploy/strategy'
require 'capistrano/logger'

require 'recipes/build/strategy'
require 'recipes/build/artifact'

def _cset(name, *args, &block)
  unless exists?(name)
    set(name, *args, &block)
  end
end

# =========================================================================
# These variables MUST be set in the client capfiles. If they are not set,
# the deploy will fail with an error.
# =========================================================================

_cset(:application) { abort "Please specify the name of your application, set :application, 'foo'" }
_cset(:repository)  { abort "Please specify the repository that houses your application's code, set :repository, 'foo'" }

_cset(:build_dir) { "/tmp/mavify/#{application}" }
_cset(:build_repository) { "#{build_dir}/repository" }

# The revision of the latest successful build
_cset(:latest_build_revision_file) { "#{build_dir}/LATEST_BUILD_REVISION" }
_cset(:source) { Capistrano::Deploy::SCM.new(scm, self) }
_cset(:builder) { Capistrano::Mavify::Build::Strategy.new("maven", self) }

# logs the command then executes it locally.
# returns the command output as a string
def run_locally(cmd)
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

def real_revision
  source.local.query_revision(revision) { |cmd| with_env("LC_ALL", "C") { run_locally(cmd) } }
end

def revision_name
  cmd = "git --git-dir=#{build_repository}/.git describe $(git --git-dir=#{build_repository}/.git rev-list --tags --max-count=1 HEAD)"
  with_env("LC_ALL", "C") { run_locally(cmd) }
end

# =========================================================================
# These are the tasks that are available to help with deploying web apps,
# and specifically, Rails applications. You can have cap give you a summary
# of them with `cap -T'.
# =========================================================================

namespace :build do
  desc <<-DESC
    Builds your project. Handy wrapper to hook into the beginning of build.
  DESC
  task :default do
    prepare_build
    run_build
  end
  
  desc <<-DESC
    Actually calls the build strategy.
  DESC
  task :run_build do
    logger.info "Revision name: #{revision_name}"
    builder.build!
    system("echo #{real_revision} > #{latest_build_revision_file}")
  end
  
  task :collect_artifacts do
  end
  
  desc <<-DESC
    Prepares the build
  DESC
  task :prepare_build do
    prepare_build_directory
    prepare_build_repository
  end
  
  desc <<-DESC
    Prepares the build directory
  DESC
  task :prepare_build_directory do
    if not File.exist?("#{build_dir}")
      Dir.mkdir("#{build_dir}")
    end
  end
  
  desc <<-DESC
    Prepares the build directory
  DESC
  task :prepare_build_repository do
    if not File.exist?(build_repository)
      system(source.checkout(real_revision, build_repository))
    else
      puts source.sync(real_revision, build_repository)
      system(source.sync(real_revision, build_repository))
    end
    logger.trace "Current head is #{source.head} at #{real_revision}" if logger
  end

end
end

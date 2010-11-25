Capistrano::Configuration.instance(:must_exist).load do
require 'benchmark'
require 'capistrano/configuration/variables'
require 'capistrano/recipes/deploy/scm'
#require 'capistrano/recipes/deploy/strategy'
require 'capistrano/logger'

require 'recipes/build/strategy'
require 'recipes/build/artifact'

require 'shared/config'

# =========================================================================
# These variables MUST be set in the client capfiles. If they are not set,
# the deploy will fail with an error.
# =========================================================================

_cset(:application) { abort "Please specify the name of your application, set :application, 'foo'" }
_cset(:repository)  { abort "Please specify the repository that houses your application's code, set :repository, 'foo'" }

_cset(:revision_name) { revision_name }

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

# runs the command locally but does not write any logs
def silent_run_locally(cmd)
  `#{cmd}`
end

def real_revision
  source.local.query_revision(revision) { |cmd| with_env("LC_ALL", "C") { silent_run_locally(cmd) } }
end

def revision_name
  cmd = "git --git-dir=#{build_repository}/.git describe $(git --git-dir=#{build_repository}/.git rev-list --tags --max-count=1 HEAD)"
  with_env("LC_ALL", "C") { silent_run_locally(cmd).strip }
end

def init_target_dir
  dir = File.join(build_target_artifacts_dir, project_name)
  FileUtils.remove_dir(dir) unless !File.exists?(dir)
  FileUtils.mkdir_p(build_target_artifacts_dir) unless File.exists?(build_target_artifacts_dir)
  Dir.mkdir(dir)
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
    prepare_target
    collect_artifacts
    add_revision_file
  end
  
  desc "Resets the build target directory"
  task :clean do
    FileUtils.remove_dir(build_target_dir)
  end
  
  desc <<-DESC
    Actually calls the build strategy.
  DESC
  task :run_build do
    logger.info "Revision name: #{revision_name}"
    builder.build!
    system("echo #{real_revision} > #{latest_build_revision_file}")
  end
  
  desc <<-DESC
    Collects the maven build artifacts and copies them to the target releae dir
  DESC
  task :collect_artifacts do
    logger.info "Collecting build artifacts to #{build_target_artifacts_dir}"
    artifacts.each do |artifact|
      artifact_copier(File.join(build_target_artifacts_dir, project_name), artifact).copy
    end
  end
  
  desc "Tags the target dir with the repository revision"
  task :add_revision_file do
    File.open(File.join(build_target_artifacts_dir, "REVISION"), "w") { |f| f.puts(real_revision) }
  end
  
  desc <<-DESC
    Prepares the target directory for artifacts.
    Deletes any existing directory
  DESC
  task :prepare_target do
    init_target_dir
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
      system(source.sync(real_revision, build_repository))
    end
    logger.trace "Current head is #{source.head} at #{real_revision}" if logger
  end
end

end

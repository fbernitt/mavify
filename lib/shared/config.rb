Capistrano::Configuration.instance(:must_exist).load do

def _cset(name, *args, &block)
  unless exists?(name)
    set(name, *args, &block)
  end
end

def _cdefine(name, *args, &block)
    set(name, *args, &block)
end

# =========================================================================
# These variables MUST be set in the client capfiles. If they are not set,
# the deploy will fail with an error.
# =========================================================================

_cset(:application) { abort "Please specify the name of your application, set :application, 'foo'" }
_cset(:repository)  { abort "Please specify the repository that houses your application's code, set :repository, 'foo'" }

_cset(:build_dir) { "/tmp/mavify/#{application}" }
_cset(:build_repository) { "#{build_dir}/repository" }
_cset(:build_target_dir) { File.join(build_dir, "target") }
_cset(:build_target_artifacts_dir) { File.join(build_target_dir, revision_name) }
_cset(:project_name) { "unknown" }

# The revision of the latest successful build
_cset(:latest_build_revision_file) { "#{build_dir}/LATEST_BUILD_REVISION" }
_cset(:source) { Capistrano::Deploy::SCM.new(scm, self) }
_cset(:builder) { Capistrano::Mavify::Build::Strategy.new("maven", self) }

def revision_name
  cmd = "git --git-dir=#{build_repository}/.git describe $(git --git-dir=#{build_repository}/.git rev-list --tags --max-count=1 HEAD)"
  with_env("LC_ALL", "C") { run_locally(cmd).strip }
end

# logs the command then executes it locally.
# returns the command output as a string
def run_locally(cmd)
  output_on_stdout=""
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

end
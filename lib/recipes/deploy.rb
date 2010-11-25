Capistrano::Configuration.instance(:must_exist).load do
  require 'benchmark'
  require 'capistrano/configuration/variables'
  require 'capistrano/recipes/deploy/scm'
  #require 'capistrano/recipes/deploy/strategy'
  require 'capistrano/logger'

require 'shared/config'

require 'recipes/deploy/strategy'

# =========================================================================
# These variables MUST be set in the client capfiles. If they are not set,
# the deploy will fail with an error.
# =========================================================================

_cset(:application) { abort "Please specify the name of your application, set :application, 'foo'" }
_cset(:repository)  { abort "Please specify the repository that houses your application's code, set :repository, 'foo'" }

# =========================================================================
# These variables may be set in the client capfile if their default values
# are not sufficient.
# =========================================================================

_cset :deploy_via, :checkout

_cset(:deploy_to) { "/tmp/#{application}" }
_cset(:revision)  { source.head }

# =========================================================================
# These variables should NOT be changed unless you are very confident in
# what you are doing. Make sure you understand all the implications of your
# changes if you do decide to muck with these!
# =========================================================================

_cset(:source)            { Capistrano::Deploy::SCM.new(scm, self) }
_cset(:real_revision)     { source.local.query_revision(revision) { |cmd| with_env("LC_ALL", "C") { run_locally(cmd) } } }

_cset(:strategy)          { Capistrano::Deploy::Strategy.new(deploy_via, self) }
_cset(:deploy_strategy) { Capistrano::Mavify::Deploy::Strategy.new("copy", self) }


# If overriding release name, please also select an appropriate setting for :releases below.
#_cset(:release_name)      { set :deploy_timestamped, true; Time.now.utc.strftime("%Y%m%d%H%M%S") }
set(:release_name)      { revision_name }

_cset :version_dir,       "releases"
_cset :shared_dir,        "shared"
_cset :shared_children,   %w(system log pids)
_cset :current_dir,       "current"

_cset(:releases_path)     { File.join(deploy_to, version_dir) }
_cset(:shared_path)       { File.join(deploy_to, shared_dir) }
_cset(:current_path)      { File.join(deploy_to, current_dir) }
_cset(:release_path)      { File.join(releases_path, release_name) }

_cset(:releases)          { capture("ls -x #{releases_path}", :except => { :no_release => true }).split.sort }
_cset(:current_release)   { File.join(releases_path, releases.last) }
_cset(:previous_release)  { releases.length > 1 ? File.join(releases_path, releases[-2]) : nil }

_cset(:current_revision)  { capture("cat #{current_path}/REVISION",     :except => { :no_release => true }).chomp }
_cset(:latest_revision)   { capture("cat #{current_release}/REVISION",  :except => { :no_release => true }).chomp }
_cset(:previous_revision) { capture("cat #{previous_release}/REVISION", :except => { :no_release => true }).chomp if previous_release }

_cset(:run_method)        { fetch(:use_sudo, true) ? :sudo : :run }

# some tasks, like symlink, need to always point at the latest release, but
# they can also (occassionally) be called standalone. In the standalone case,
# the timestamped release_path will be inaccurate, since the directory won't
# actually exist. This variable lets tasks like symlink work either in the
# standalone case, or during deployment.
_cset(:latest_release) { exists?(:deploy_timestamped) ? release_path : current_release }

# =========================================================================
# These are helper methods that will be available to your recipes.
# =========================================================================

# Auxiliary helper method for the `deploy:check' task. Lets you set up your
# own dependencies.
def depend(location, type, *args)
  deps = fetch(:dependencies, {})
  deps[location] ||= {}
  deps[location][type] ||= []
  deps[location][type] << args
  set :dependencies, deps
end

# Temporarily sets an environment variable, yields to a block, and restores
# the value when it is done.
def with_env(name, value)
  saved, ENV[name] = ENV[name], value
  yield
ensure
  ENV[name] = saved
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


# If a command is given, this will try to execute the given command, as
# described below. Otherwise, it will return a string for use in embedding in
# another command, for executing that command as described below.
#
# If :run_method is :sudo (or :use_sudo is true), this executes the given command
# via +sudo+. Otherwise is uses +run+. If :as is given as a key, it will be
# passed as the user to sudo as, if using sudo. If the :as key is not given,
# it will default to whatever the value of the :admin_runner variable is,
# which (by default) is unset.
#
# THUS, if you want to try to run something via sudo, and what to use the
# root user, you'd just to try_sudo('something'). If you wanted to try_sudo as
# someone else, you'd just do try_sudo('something', :as => "bob"). If you
# always wanted sudo to run as a particular user, you could do 
# set(:admin_runner, "bob").
def try_sudo(*args)
  options = args.last.is_a?(Hash) ? args.pop : {}
  command = args.shift
  raise ArgumentError, "too many arguments" if args.any?

  as = options.fetch(:as, fetch(:admin_runner, nil))
  via = fetch(:run_method, :sudo)
  if command
    invoke_command(command, :via => via, :as => as)
  elsif via == :sudo
    sudo(:as => as)
  else
    ""
  end
end

# Same as sudo, but tries sudo with :as set to the value of the :runner
# variable (which defaults to "app").
def try_runner(*args)
  options = args.last.is_a?(Hash) ? args.pop : {}
  args << options.merge(:as => fetch(:runner, "app"))
  try_sudo(*args)
end

# =========================================================================
# These are the tasks that are available to help with deploying web apps,
# and servers
# =========================================================================

namespace :deploy do
  desc <<-DESC
    Deploys your project. This calls both `update' and `restart'. Note that \
    this will generally only work for applications that have already been deployed \
    once. For a "cold" deploy, you'll want to take a look at the `deploy:cold' \
    task, which handles the cold start specifically.
  DESC
  task :default do
    puts "Would deploy to #{revision_name} and #{release_path}"
    update
    #restart
  end

  desc <<-DESC
    Copies your project and updates the symlink. It does this in a \
    transaction, so that if either `update_code' or `symlink' fail, all \
    changes made to the remote servers will be rolled back, leaving your \
    system in the same state it was in before `update' was invoked. Usually, \
    you will want to call `deploy' instead of `update', but `update' can be \
    handy if you want to deploy, but not immediately restart your application.
  DESC
  task :update do
    transaction do
      update_code
      symlink
    end
  end
  
  desc <<-DESC
    Copies your project to the remote servers. This is the first stage \
    of any deployment; moving your updated code and assets to the deployment \
    servers. You will rarely call this task directly, however; instead, you \
    should call the `deploy' task (to do a complete deploy) or the `update' \
    task (if you want to perform the `restart' task separately).

    You will need to make sure you set the :scm variable to the source \
    control software you are using (it defaults to :subversion), and the \
    :deploy_via variable to the strategy you want to use to deploy (it \
    defaults to :checkout).
  DESC
  task :update_code, :except => { :no_release => true } do
    on_rollback { run "rm -rf #{release_path}; true" }
    deploy_strategy.deploy!
    #finalize_update
  end

  desc <<-DESC
    Updates the symlink to the most recently deployed version. Capistrano works \
    by putting each new release of your application in its own directory. When \
    you deploy a new version, this task's job is to update the `current' symlink \
    to point at the new version. You will rarely need to call this task \
    directly; instead, use the `deploy' task (which performs a complete \
    deploy, including `restart') or the 'update' task (which does everything \
    except `restart').
  DESC
  task :symlink, :except => { :no_release => true } do
  end
end
end
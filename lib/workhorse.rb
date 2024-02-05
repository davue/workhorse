require 'active_record'
require 'active_support/all'
require 'concurrent'
require 'socket'
require 'uri'

require 'workhorse/enqueuer'
require 'workhorse/scoped_env'
require 'workhorse/active_job_extension'

module Workhorse
  # Check if the available Arel version is greater or equal than 7.0.0
  AREL_GTE_7 = Gem::Version.new(Arel::VERSION) >= Gem::Version.new('7.0.0')

  extend Workhorse::Enqueuer

  # Returns the performer currently performing the active job. This can only be
  # called from within a job and the same thread.
  def self.performer
    Thread.current[:workhorse_current_performer] \
      || fail('No performer is associated with the current thread. This method must always be called inside of a job.')
  end

  # A worker will log an error and, if defined, call the on_exception callback,
  # if it couldn't obtain the global lock for the specified number of times in a
  # row.
  mattr_accessor :max_global_lock_fails
  self.max_global_lock_fails = 10

  mattr_accessor :tx_callback
  self.tx_callback = proc do |*args, &block|
    ActiveRecord::Base.transaction(*args, &block)
  end

  mattr_accessor :on_exception
  self.on_exception = proc do |exception|
    # Do something with this exception, i.e.
    # ExceptionNotifier.notify_exception(exception)
  end

  # If set to `false`, shell handler (CLI) won't lock commands using a lockfile.
  # You should generally only disable this if you are performing the locking
  # yourself (e.g. in a wrapper script).
  mattr_accessor :lock_shell_commands
  self.lock_shell_commands = true

  # If set to `true`, the defined `on_exception` will not be called when the
  # poller encounters an exception and the worker has to be shut down. The
  # exception will still be logged.
  mattr_accessor :silence_poller_exceptions
  self.silence_poller_exceptions = false

  # If set to `true`, the `watch` command won't produce any output. This does
  # not include warnings such as the "development mode" warning.
  mattr_accessor :silence_watcher
  self.silence_watcher = false

  mattr_accessor :perform_jobs_in_tx
  self.perform_jobs_in_tx = true

  # If enabled, each poller will attempt to clean jobs that are stuck in state
  # 'locked' or 'running' when it is starting up.
  mattr_accessor :clean_stuck_jobs
  self.clean_stuck_jobs = false

  # This setting is for {Workhorse::Jobs::DetectStaleJobsJob} and specifies the
  # maximum number of seconds a job is allowed to stay 'locked' before this job
  # throws an exception. Set this to 0 to skip this check.
  mattr_accessor :stale_detection_locked_to_started_threshold
  self.stale_detection_locked_to_started_threshold = 3 * 60

  # This setting is for {Workhorse::Jobs::DetectStaleJobsJob} and specifies the
  # maximum number of seconds a job is allowed to run before this job throws an
  # exception. Set this to 0 to skip this check.
  mattr_accessor :stale_detection_run_time_threshold
  self.stale_detection_run_time_threshold = 12 * 60

  # Maximum memory for a worker in MB. If this memory limit (RSS / resident
  # size) is reached for a worker process, the 'watch' command will restart said
  # worker. Set this to 0 disable this feature.
  mattr_accessor :max_worker_memory_mb
  self.max_worker_memory_mb = 0

  def self.setup
    yield self
  end
end

require 'workhorse/db_job'
require 'workhorse/performer'
require 'workhorse/poller'
require 'workhorse/pool'
require 'workhorse/worker'
require 'workhorse/jobs/run_rails_op'
require 'workhorse/jobs/run_active_job'
require 'workhorse/jobs/cleanup_succeeded_jobs'
require 'workhorse/jobs/detect_stale_jobs_job'

# Daemon functionality is not available on java platforms
if RUBY_PLATFORM != 'java'
  require 'workhorse/daemon'
  require 'workhorse/daemon/shell_handler'
end

if defined?(ActiveJob)
  require 'active_job/queue_adapters/workhorse_adapter'
end

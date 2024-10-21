module ActiveJob
  module QueueAdapters
    # == Workhorse adapter for Active Job
    #
    # Workhorse is a multi-threaded job backend with database queuing for ruby.
    # Jobs are persisted in the database using ActiveRecird.
    # Read more about Workhorse {here}[https://github.com/sitrox/activejob].
    #
    # To use Workhorse, set the queue_adapter config to +:workhorse+.
    #
    #   Rails.application.config.active_job.queue_adapter = :workhorse
    class WorkhorseAdapter
      # Defines whether enqueuing should happen implicitly to after commit when called
      # from inside a transaction. Most adapters should return true, but some adapters
      # that use the same database as Active Record and are transaction aware can return
      # false to continue enqueuing jobs as part of the transaction.
      def enqueue_after_transaction_commit?
        false
      end

      def enqueue(job) # :nodoc:
        Workhorse.enqueue_active_job(job)
      end

      def enqueue_at(job, timestamp = Time.now) # :nodoc:
        Workhorse.enqueue_active_job(job, perform_at: timestamp)
      end
    end
  end
end

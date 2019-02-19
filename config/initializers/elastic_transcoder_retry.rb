if Settings.active_job.queue_adapter.to_sym == :active_elastic_job
  ActiveEncode::EngineAdapters::ElasticTranscoderAdapter.class_eval do
    alias_method :_create, :create

    def create(*args)
      on_retry = Proc.new do |exception, try, elapsed_time, next_interval|
        log "#{exception.class}: '#{exception.message}' - #{try} tries in #{elapsed_time} seconds and #{next_interval} seconds until the next try."
      end

      Retriable.retriable(tries: 10, on: Aws::ElasticTranscoder::Errors, on_retry: on_retry) do
        _create(*args)
      end
    end
  end
end
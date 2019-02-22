Aws::ElasticTranscoder::Client.prepend(
  Module.new do
    [:create_job, :read_job, :cancel_job, :list_presets, :read_preset, :read_pipeline, :create_preset].each do |method|
      define_method(method) do |*method_args|
        retry_proc = ->(exception, try, elapsed_time, next_interval) do
          Rails.logger.warn("Exception calling `#{self.class.name}##{method}': #{exception.class}: `#{exception.message}' - #{try} tries in #{elapsed_time} seconds and #{next_interval} seconds until the next try.")
        end
      
        Rails.logger.info("Calling `#{self.class.name}##{method}' with retriable enabled.")
        Retriable.retriable(tries: 10, on_retry: retry_proc) do
          super(*method_args)
        end
      end
    end
  end  
)
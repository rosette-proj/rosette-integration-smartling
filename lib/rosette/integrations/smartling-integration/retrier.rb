# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration

      class Retrier
        DEFAULT_MAX_RETRIES = 5

        def self.retry(options = {}, &block)
          new(options.fetch(:times, DEFAULT_MAX_RETRIES), block)
        end

        attr_reader :max_retries, :errors, :proc

        def initialize(max_retries, proc)
          @max_retries = max_retries
          @errors = {}
          @proc = proc
        end

        def on_error(error_class, &block)
          @errors[error_class] = block
          self
        end

        def execute
          retries = 0
          begin
            proc.call
          rescue *errors.keys => e
            retries += 1
            errors[e.class].call(e, retries) if errors[e.class]
            retry unless retries >= max_retries
            raise e
          end
        end
      end

    end
  end
end

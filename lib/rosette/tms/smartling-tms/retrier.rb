# encoding: UTF-8

module Rosette
  module Tms
    module SmartlingTms

      class Retrier
        DEFAULT_MAX_RETRIES = 5
        DEFAULT_BASE_SLEEP_SECONDS = 1

        def self.retry(options = {}, &block)
          new(options.fetch(:times, DEFAULT_MAX_RETRIES), block)
        end

        attr_reader :max_retries, :errors, :proc

        def initialize(max_retries, proc)
          @max_retries = max_retries
          @errors = {}
          @proc = proc
        end

        def on_error(error_class, options = {}, &block)
          @errors[error_class] = { proc: block, options: options }
          self
        end

        def execute
          retries = 0
          begin
            proc.call
          rescue *errors.keys => e
            handler_classes = handler_classes_for(e.class)

            handler_class = handler_classes.find do |handler_class|
              options = errors.fetch(handler_class, {}).fetch(:options, {})
              should_have_rescued?(e, options)
            end

            handler = errors[handler_class]
            raise e unless handler
            options = handler.fetch(:options, {})

            retries += 1
            handler[:proc].call(e, retries) if handler[:proc]
            sleep calc_sleep_time(retries, options)
            retry unless retries >= max_retries
            raise e
          end
        end

        private

        def handler_classes_for(klass)
          errors.each_with_object([]) do |(error_class, _), ret|
            if ancestor_class = ancestor_handler_class_for(error_class)
              ret << ancestor_class
            end
          end
        end

        def ancestor_handler_class_for(klass)
          klass.ancestors.find do |ancestor|
            errors.include?(ancestor)
          end
        end

        def should_have_rescued?(error, options)
          regex = options.fetch(:message, //)
          !!(error.message =~ regex)
        end

        def calc_sleep_time(retries, options)
          if options[:backoff]
            base_sleep_seconds = options.fetch(
              :base_sleep_seconds, DEFAULT_BASE_SLEEP_SECONDS
            )

            # exponential backoff
            base_sleep_seconds * (2 ** (retries - 1))
          else
            0
          end
        end
      end

    end
  end
end

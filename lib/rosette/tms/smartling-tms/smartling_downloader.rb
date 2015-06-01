# encoding: UTF-8

module Rosette
  module Tms
    module SmartlingTms
      class SmartlingDownloader

        def self.download_file(smartling_api, file_uri, locale)
          retrier = Retrier.retry(times: 9, base_sleep_seconds: 2) do
            smartling_api.download(file_uri, locale: locale.code)
          end

          retrier
            .on_error(RuntimeError, message: /RESOURCE_LOCKED/, backoff: true)
            .on_error(RuntimeError, message: /VALIDATION_ERROR/, backoff: true)
            .on_error(Exception)
            .execute
        end

      end
    end
  end
end

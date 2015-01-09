# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class SmartlingCompleter

        attr_reader :configuration, :smartling_apis, :pullers

        def initialize(configuration, smartling_apis, pullers)
          @smartling_apis = smartling_apis
          @configuration = configuration
          @pullers = pullers
        end

        def complete(repo_name, locales)
          file_hash ||= Hash.new { |h, key| h[key] = [] }
          file_uris_to_files = {}

          locales.each do |locale|
            puller = puller_for_locale(locale)
            completed_files = puller.completed_files_map[repo_name]
            completed_files.each do |file|
              file_uris_to_files[file.file_uri] ||= file
              file_hash[file.file_uri] << locale
            end
          end

          file_hash.each do |file_uri, completed_locales|
            if completed_locales.sort == locales.sort
              Rosette.logger.info("Deleting file from Smartling: #{file_uri}")
              file = file_uris_to_files[file_uri]

              configuration.datastore.add_or_update_commit_log(
                file.repo_name, file.commit_id, nil, Rosette::DataStores::PhraseStatus::TRANSLATED
              )

              smartling_apis[repo_name].delete(file_uri)
            end
          end
        end

        private

        def puller_for_locale(locale)
          pullers.find { |puller| puller.locale == locale }
        end

      end
    end
  end
end

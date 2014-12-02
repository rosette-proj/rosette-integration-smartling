# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class SmartlingCompleter

        attr_reader :configuration, :smartling_api

        def initialize(configuration, smartling_api)
          @smartling_api = smartling_api
          @configuration = configuration
        end

        def complete(locales, repo_name)
          file_hash ||= Hash.new { |h, key| h[key] = [] }
          file_uris_to_files = {}

          locales.each do |locale|
            file_list_response = smartling_api.list(locale: locale)
            file_list = SmartlingFileList.from_api_response(file_list_response)

            file_list.each do |file|
              if file.repo_name == repo_name
                file_uris_to_files[file.file_uri] ||= file

                if file.phrase_count == file.translated_count
                  file_hash[file.file_uri] << locale
                end
              end
            end
          end

          file_hash.each do |file_uri, completed_locales|
            if completed_locales.sort == locales.sort
              Rosette.logger.info("Deleting file from Smartling: #{file_uri}")
              file = file_uris_to_files[file_uri]

              configuration.datastore.add_or_update_commit_log(
                file.repo_name, file.commit_id, nil, Rosette::DataStores::PhraseStatus::TRANSLATED
              )

              smartling_api.delete(file_uri)
            end
          end
        end

      end
    end
  end
end

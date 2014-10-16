module Rosette
  module Integrations
    module Smartling
      class SmartlingCompleter < SmartlingOperation

        attr_reader :configuration

        def initialize(configuration, api_options = {})
          super(api_options)
          @configuration = configuration
        end

        def complete(locales)
          file_hash ||= Hash.new{ |h, key| h[key] = [] }

          file_uris_to_files = {}
          locales.each do |locale|
            file_list_response = api.list(locale: locale)
            file_list = SmartlingFileList.from_api_response(file_list_response)

            file_list.each do |file|
              file_uris_to_files[file.file_uri] ||= file

              if file.phrase_count == file.translated_count
                file_hash[file.file_uri] << locale
              end
            end
          end

          file_hash.each do |file_uri, completed_locales|
            if completed_locales.sort == locales.sort
              Rosette.logger.info("Deleting file from Smartling: #{file_uri}")
              file = file_uris_to_files[file_uri]
              configuration.datastore.add_or_update_commit_log(
                file.repo_name, file.commit_id, Rosette::DataStores::PhraseStatus::TRANSLATED
              )
              api.delete(file_uri)
            end
          end
        end

      end
    end
  end
end

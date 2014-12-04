# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class SmartlingPuller

        attr_reader :rosette_config, :smartling_api

        def initialize(rosette_config, smartling_api)
          @rosette_config = rosette_config
          @smartling_api = smartling_api
        end

        def pull(locale, extractor_id, rosette_api, encoding = nil)
          file_list_response = smartling_api.list(locale: locale)
          file_list = SmartlingFileList.from_api_response(file_list_response)

          file_list.each do |file|
            rosette_config.datastore.add_or_update_commit_log_locale(
              file.commit_id, locale, file.translated_count
            )

            repo_config = rosette_config.get_repo(file.repo_name)
            encodings = repo_config.extractor_configs.map(&:encoding).uniq

            if encodings.size > 1 && !encoding
              raise Errors::AmbiguousEncodingError,
                'More than one encoding found. Please specify encoding when you call this method.'
            else
              encoding = encoding || encodings.first

              file_contents = smartling_api.download(
                file.file_uri, locale: locale
              ).force_encoding(encoding)

              extractor = Rosette::Core::ExtractorId.resolve(extractor_id).new

              extractor.extract_each_from(file_contents) do |phrase_object|
                rosette_api.add_or_update_translation({
                  phrase_object.index_key => phrase_object.index_value,
                  ref: file.commit_id,
                  translation: phrase_object.key,
                  locale: locale,
                  repo_name: repo_config.name
                })
              end
            end
          end
        end

      end
    end
  end
end

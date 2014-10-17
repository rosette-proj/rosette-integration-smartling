# encoding: UTF-8

module Rosette
  module Integrations
    module Smartling
      class SmartlingPuller < SmartlingOperation

        attr_reader :configuration

        def initialize(configuration, api_options = {})
          super(api_options)
          @configuration = configuration
        end

        def pull(locale, extractor_id, rosette_api, encoding = nil)
          file_list_response = api.list(locale: locale)
          file_list = SmartlingFileList.from_api_response(file_list_response)

          file_list.each do |file|
            configuration.datastore.add_or_update_commit_log_locale(
              file.commit_id, locale, file.translated_count
            )

            repo_config = configuration.get_repo(file.repo_name)
            encodings = repo_config.extractor_configs.map(&:encoding).uniq

            if encodings.size > 1 && !encoding
              raise 'More than one encoding found. Please specify encoding.'
            else
              encoding = encoding || encodings.first
              file_contents = api.download(file.file_uri, locale: locale).force_encoding(encoding)

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

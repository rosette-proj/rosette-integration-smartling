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

        def pull(locale, extractor_id, encoding = nil)
          file_list_response = smartling_api.list(locale: locale)
          file_list = SmartlingFile.list_from_api_response(file_list_response)

          file_list.each do |file|
            next unless file.commit_id == 'aa9d4ce46afce3cd8c539cc55187715b1149b075'
            next unless repo_names.include?(file.repo_name)

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
                puts phrase_object.index_value
                begin
                  cmd = Rosette::Core::Commands::AddOrUpdateTranslationCommand.new(rosette_config)
                    .set_repo_name(repo_config.name)
                    .set_locale(locale)
                    .set_translation(phrase_object.key)
                    .set_ref(file.commit_id)
                    .send("set_#{phrase_object.index_key}", phrase_object.index_value)

                  cmd.execute
                rescue => e
                  rosette_config.error_reporter.report_warning(e, commit_id: file.commit_id, locale: locale)
                end
              end
            end
          end
        end

        private

        def repo_names
          @repo_names ||= rosette_config.repo_configs.map(&:name)
        end

      end
    end
  end
end

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

        def pull(locale, extractor_id)
          file_list_response = smartling_api.list(locale: locale)
          file_list = SmartlingFile.list_from_api_response(file_list_response)

          file_list.each do |file|
            next unless repo_names.include?(file.repo_name)

            rosette_config.datastore.add_or_update_commit_log_locale(
              file.commit_id, locale, file.translated_count
            )

            repo_config = rosette_config.get_repo(file.repo_name)

            extractor_config = repo_config.get_extractor_config(extractor_id)

            file_contents = smartling_api.download(
              file.file_uri, locale: locale
            ).force_encoding(extractor_config.encoding)

            extractor = extractor_config.extractor

            extractor.extract_each_from(file_contents) do |phrase_object|
              begin
                Rosette::Core::Commands::AddOrUpdateTranslationCommand.new(rosette_config)
                  .set_repo_name(repo_config.name)
                  .set_locale(locale)
                  .set_translation(phrase_object.key)
                  .set_ref(file.commit_id)
                  .send("set_#{phrase_object.index_key}", phrase_object.index_value)
                  .execute
              rescue => e
                rosette_config.error_reporter.report_warning(
                  e, commit_id: file.commit_id, locale: locale
                )
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

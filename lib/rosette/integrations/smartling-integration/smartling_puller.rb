# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class SmartlingPuller

        attr_reader :rosette_config, :smartling_apis, :completed_files_map, :locale

        def initialize(rosette_config, smartling_apis, locale)
          @rosette_config = rosette_config
          @smartling_apis = smartling_apis
          @locale = locale
          @completed_files_map = Hash.new { |h, key| h[key] = [] }
        end

        def pull(repo_name, extractor_id)
          file_list_for_repo(repo_name).each do |file|
            next unless file.repo_name == repo_name

            rosette_config.datastore.add_or_update_commit_log_locale(
              file.commit_id, locale, file.translated_count
            )

            repo_config = rosette_config.get_repo(file.repo_name)
            extractor_config = repo_config.get_extractor_config(extractor_id)

            file_contents = smartling_apis[repo_name].download(
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

            @completed_files_map[repo_name] << file if file.complete?
          end
        end

        private

        def file_list_for_repo(repo_name)
          file_lists[repo_name] ||= begin
            file_list_response = smartling_apis[repo_name].list(locale: locale)
            SmartlingFile.list_from_api_response(file_list_response)
          end
        end

        def file_lists
          @file_lists ||= {}
        end

      end
    end
  end
end

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
          each_file_for_repo(repo_name) do |file|
            next unless file.repo_name == repo_name
            next unless file_has_changed?(repo_name, file)

            potential_files = rosette_config.datastore.file_list_for_repo(repo_name)

            snapshot = Rosette::Core::Commands::RepoSnapshotCommand.new(rosette_config)
              .set_repo_name(repo_name)
              .set_commit_id(file.commit_id)
              .set_paths(potential_files)
              .execute

            snapshot_commit_ids = snapshot.values.uniq.compact

            rosette_config.datastore.add_or_update_commit_log_locale(
              file.commit_id, locale, file.translated_count
            )

            # Update the phrase count to avoid discrepancies between this and
            # the initial number reported when the file is pushed (uploaded).
            # For some reason these numbers can differ, meaning the file is
            # either over-translated (more translations than phrases) or
            # under-translated (less translations than phrases), even though
            # the Smartling UI reports 100% for all locales.
            rosette_config.datastore.add_or_update_commit_log(
              repo_name, file.commit_id, nil, Rosette::DataStores::PhraseStatus::PENDING,
              file.phrase_count
            )

            repo_config = rosette_config.get_repo(file.repo_name)
            extractor_config = repo_config.get_extractor_config(extractor_id)
            extractor = extractor_config.extractor

            file_contents = download_file(file, locale)
              .force_encoding(extractor_config.encoding)

            extractor.extract_each_from(file_contents) do |phrase_object|
              begin
                Rosette::Core::Commands::AddOrUpdateTranslationCommand.new(rosette_config)
                  .set_repo_name(repo_config.name)
                  .set_locale(locale)
                  .set_translation(phrase_object.key)
                  .set_refs(snapshot_commit_ids)
                  .send("set_#{phrase_object.index_key}", phrase_object.index_value)
                  .execute
              rescue Rosette::DataStores::Errors::PhraseNotFoundError => e
                rosette_config.error_reporter.report_warning(
                  e, commit_id: file.commit_id, locale: locale
                )
              end
            end

            @completed_files_map[repo_name] << file if file.complete?
          end
        end

        private

        def file_has_changed?(repo_name, file)
          status = rosette_config.datastore.commit_log_status(
            repo_name, file.commit_id
          )

          if status
            locale_status = status.fetch(:locales, []).find do |l|
              l.fetch(:locale, nil) == locale
            end

            (locale_status || {}).fetch(:translated_count, nil) != file.translated_count
          else
            true
          end
        end

        def each_file_for_repo(repo_name, &block)
          if block_given?
            if file_lists.include?(repo_name)
              file_lists[repo_name].each(&block)
            else
              counter = 0
              list = get_file_list(repo_name, counter)
              file_lists[repo_name] = list

              while list.size > 0
                list.each(&block)
                list = get_file_list(repo_name, counter + 1)
                file_lists[repo_name] += list
                counter += list.size + 1
              end
            end
          else
            to_enum(__method__, repo_name)
          end
        end

        def get_file_list(repo_name, offset, limit = 100)
          Retrier.retry(times: 5) do
            SmartlingFile.list_from_api_response(
              smartling_apis[repo_name].list(
                locale: locale, offset: offset, limit: limit
              )
            )
          end.on_error(RestClient::RequestTimeout).execute
        end

        def download_file(file, locale)
          Retrier.retry(times: 5) do
            smartling_apis[file.repo_name].download(
              file.file_uri, locale: locale
            )
          end.on_error(RestClient::RequestTimeout).execute
        end

        def file_lists
          @file_lists ||= {}
        end

      end
    end
  end
end

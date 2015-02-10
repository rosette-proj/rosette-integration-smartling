# encoding: UTF-8

require 'set'
require 'concurrent'

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class SmartlingPuller

        DEFAULT_THREAD_POOL_SIZE = 15

        attr_reader :rosette_config
        attr_reader :repo_config, :serializer_id, :extractor_id
        attr_reader :thread_pool_size, :logger

        def initialize(rosette_config)
          @rosette_config = rosette_config
          @thread_pool_size = DEFAULT_THREAD_POOL_SIZE
          @logger = Rosette.logger
        end

        def set_repo_config(repo_config)
          @repo_config = repo_config
          self
        end

        def set_serializer_id(serializer_id)
          @serializer_id = serializer_id
          self
        end

        def set_extractor_id(extractor_id)
          @extractor_id = extractor_id
          self
        end

        def set_thread_pool_size(size)
          @thread_pool_size = size
          self
        end

        def set_logger(logger)
          @logger = logger
          self
        end

        def pull
          if thread_pool_size > 1
            pull_asynchronously
          else
            pull_synchronously
          end
        end

        private

        def pull_synchronously
          head_refs = repo_config.repo.all_head_refs
          head_refs.each_with_index do |head_ref, idx|
            pull_head(head_ref)
            logger.info(
              "#{repo_config.name}: #{idx} of #{head_refs.size} pulled"
            )
          end
        end

        def pull_asynchronously
          pool = Concurrent::FixedThreadPool.new(thread_pool_size)
          head_refs = repo_config.repo.all_head_refs

          head_refs.each do |head_ref|
            pool << Proc.new { pull_head(head_ref) }
          end

          drain_pool(pool, head_refs.size)
        end

        def drain_pool(pool, total)
          pool.shutdown
          last_completed_count = 0

          while pool.shuttingdown?
            current_completed_count = pool.completed_task_count

            if current_completed_count > last_completed_count
              logger.info("#{repo_config.name}: #{current_completed_count} of #{total} pulled")
            end

            last_completed_count = current_completed_count
          end
        end

        def pull_head(head_ref)
          rev_commit = repo_config.repo.get_rev_commit(head_ref)
          phrases = phrases_for(rev_commit.getId.name)
          file_name = rev_commit.getId.name
          uploader = build_uploader(phrases, file_name)

          begin
            sync_head(uploader, rev_commit.getId.name)
          rescue => e
            # report error but keep pulling the rest of the heads
            rosette_config.error_reporter.report_error(e)
          ensure
            cleanup(uploader)
          end
        end

        def sync_head(uploader, commit_id)
          uploader.upload

          repo_config.locales.each do |locale|
            download(uploader, locale, commit_id)
          end
        end

        def cleanup(uploader)
          delete_file(uploader.destination_file_uri)
        end

        def download(uploader, locale, commit_id)
          contents = download_file(uploader.destination_file_uri, locale)
            .force_encoding(extractor_config.encoding)

          import_phrases_from(contents, locale, uploader, commit_id)
          update_commit_log_for(locale, uploader, commit_id)
        end

        def import_phrases_from(contents, locale, uploader, commit_id)
          extractor.extract_each_from(contents) do |phrase_object|
            begin
              Rosette::Core::Commands::AddOrUpdateTranslationCommand.new(rosette_config)
                .set_repo_name(repo_config.name)
                .set_locale(locale.code)
                .set_translation(phrase_object.key)
                .set_refs(commit_ids_from(uploader.phrases))
                .send("set_#{phrase_object.index_key}", phrase_object.index_value)
                .execute
            rescue Rosette::DataStores::Errors::PhraseNotFoundError => e
              rosette_config.error_reporter.report_warning(
                e, commit_id: commit_id, locale: locale
              )
            end
          end
        end

        def update_commit_log_for(locale, uploader, commit_id)
          file = file_status_for(uploader.destination_file_uri, locale)

          rosette_config.datastore.add_or_update_commit_log(
            repo_config.name, commit_id, nil,
            Rosette::DataStores::PhraseStatus::PENDING,
            file.phrase_count
          )
        end

        def commit_ids_from(phrases)
          phrases.each_with_object(Set.new) do |phrase, ret|
            ret << phrase.commit_id
          end
        end

        def download_file(file_uri, locale)
          Retrier.retry(times: 3) do
            smartling_api.download(file_uri, locale: locale.code)
          end.on_error(Exception).execute
        end

        def delete_file(file_uri)
          Retrier.retry(times: 3) do
            smartling_api.delete(file_uri)
          end.on_error(Exception).execute
        end

        def file_status_for(file_uri, locale)
          Retrier.retry(times: 3) do
            SmartlingFile.from_api_response(
              smartling_api.status(file_uri, locale: locale.code)
            )
          end.on_error(Exception).execute
        end

        def build_uploader(phrases, file_name)
          SmartlingIntegration::SmartlingUploader.new(rosette_config)
            .set_repo_config(repo_config)
            .set_phrases(phrases)
            .set_file_name(file_name)
            .set_serializer_id(serializer_id)
        end

        def phrases_for(commit_id)
          Rosette::Core::Commands::SnapshotCommand.new(rosette_config)
            .set_repo_name(repo_config.name)
            .set_commit_id(commit_id)
            .execute
        end

        def extractor_config
          @extractor_config ||=
            repo_config.get_extractor_config(extractor_id)
        end

        def extractor
          @extractor ||= extractor_config.extractor
        end

        def integration_config
          @integration_config ||=
            repo_config.get_integration('smartling')
        end

        def smartling_api
          @smartling_api ||= integration_config.smartling_api
        end

      end
    end
  end
end

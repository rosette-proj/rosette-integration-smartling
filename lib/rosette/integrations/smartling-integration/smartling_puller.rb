# encoding: UTF-8

require 'set'
require 'concurrent'

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class SmartlingPuller

        DEFAULT_THREAD_POOL_SIZE = 10

        PULL_STATUSES = [
          Rosette::DataStores::PhraseStatus::PENDING,
          Rosette::DataStores::PhraseStatus::PULLING,
          Rosette::DataStores::PhraseStatus::PULLED
        ]

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
          if thread_pool_size > 0
            pull_asynchronously
          else
            pull_synchronously
          end
        end

        private

        def pull_synchronously
          datastore = rosette_config.datastore
          tm = build_translation_memory

          pending_count = datastore.commit_log_with_status_count(
            repo_config.name, PULL_STATUSES
          )

          datastore.each_commit_log_with_status(repo_config.name, PULL_STATUSES).with_index do |commit_log, idx|
            pull_commit(tm, commit_log)
            logger.info(
              "#{repo_config.name}: #{idx} of #{pending_count} pulled"
            )
          end

          write_checksums(tm)
        end

        def pull_asynchronously
          pool = Concurrent::FixedThreadPool.new(thread_pool_size)
          datastore = rosette_config.datastore
          tm = build_translation_memory

          pending_count = datastore.commit_log_with_status_count(
            repo_config.name, PULL_STATUSES
          )

          datastore.each_commit_log_with_status(repo_config.name, PULL_STATUSES) do |commit_log|
            pool << Proc.new { pull_commit(tm, commit_log) }
          end

          drain_pool(pool, pending_count)
          write_checksums(tm)
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

        def write_checksums(tm)
          repo_config.locales.each do |locale|
            rosette_config.cache.write(
              tm_checksum_key(locale), tm.checksum_for(locale)
            )
          end
        end

        def pull_commit(tm, commit_log)
          commit_id = commit_log.commit_id
          snapshot = snapshot_for(commit_id)
          phrases = phrases_for(snapshot)
          commit_ids = commit_ids_from(phrases)

          repo_config.locales.each do |locale|
            sync_commit(tm, commit_log, locale, phrases, commit_ids)
          end

          update_logs(commit_log)
        rescue Java::OrgEclipseJgitErrors::MissingObjectException => e
          commit_log.missing
          save_log(commit_log)
        rescue => e
          # report error but keep pulling the rest of the commits
          rosette_config.error_reporter.report_error(e, {
            commit_id: commit_id
          })
        end

        def update_logs(commit_log)
          if commit_log.phrase_count == 0
            commit_log.translate!

            repo_config.locales.each do |locale|
              rosette_config.datastore.add_or_update_commit_log_locale(
                commit_log.commit_id, locale.code, 0
              )
            end
          else
            commit_log.pull
          end

          save_log(commit_log)
        end

        def save_log(commit_log)
          rosette_config.datastore.add_or_update_commit_log(
            repo_config.name, commit_log.commit_id, nil, commit_log.status
          )
        end

        def sync_commit(tm, commit_log, locale, phrases, commit_ids)
          if should_import_translations?(tm, locale, commit_log)
            phrases.each do |phrase|
              sync_phrase(phrase, tm, commit_log, locale, commit_ids)
            end
          end
        end

        def sync_phrase(phrase, tm, commit_log, locale, commit_ids)
          if translation = tm.translation_for(locale, phrase)
            import_translation(
              phrase.meta_key, translation, locale, commit_ids
            )
          else
            rosette_config.error_reporter.report_warning(
              "No translation found for #{locale.code}, #{phrase.meta_key} " +
                "('#{phrase.key}'), #{commit_log.commit_id}"
            )
          end
        end

        def should_import_translations?(tm, locale, commit_log)
          translations_have_changed?(tm, locale) ||
            commit_log.status == Rosette::DataStores::PhraseStatus::PENDING
        end

        def translations_have_changed?(tm, locale)
          if checksum = rosette_config.cache.read(tm_checksum_key(locale))
            checksum != tm.checksum_for(locale)
          else
            true
          end
        end

        def tm_checksum_key(locale)
          "#{repo_config.name}/tm/#{locale.code}/checksum"
        end

        def build_translation_memory
          TranslationMemoryBuilder.new(rosette_config)
            .set_repo_config(repo_config)
            .set_thread_pool_size(thread_pool_size)
            .set_logger(logger)
            .build
        end

        def import_translation(meta_key, translation, locale, commit_ids)
          Rosette::Core::Commands::AddOrUpdateTranslationCommand.new(rosette_config)
            .set_repo_name(repo_config.name)
            .set_locale(locale.code)
            .set_translation(translation)
            .set_refs(commit_ids)
            .set_meta_key(meta_key)
            .execute
        rescue Rosette::DataStores::Errors::PhraseNotFoundError => e
          rosette_config.error_reporter.report_warning(e, {
            commit_ids: commit_ids, locale: locale
          })
        end

        def commit_ids_from(phrases)
          phrases.each_with_object(Set.new) do |phrase, ret|
            ret << phrase.commit_id
          end
        end

        def snapshot_for(commit_id)
          Rosette::Core::Commands::RepoSnapshotCommand.new(rosette_config)
            .set_repo_name(repo_config.name)
            .set_commit_id(commit_id)
            .execute
        end

        def phrases_for(snapshot)
          rosette_config.datastore.phrases_by_commits(repo_config.name, snapshot).to_a
        end

      end
    end
  end
end

# encoding: UTF-8

require 'concurrent'

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class SmartlingPusher

        DEFAULT_THREAD_POOL_SIZE = 10

        attr_reader :rosette_config, :repo_config
        attr_reader :serializer_id, :thread_pool_size
        attr_reader :logger

        def initialize(rosette_config)
          @rosette_config = rosette_config
          @thread_pool_size = DEFAULT_THREAD_POOL_SIZE
        end

        def set_repo_config(repo_config)
          @repo_config = repo_config
          self
        end

        def set_serializer_id(serializer_id)
          @serializer_id = serializer_id
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

        def push
          if thread_pool_size > 0
            push_asynchronously
          else
            push_synchronously
          end
        end

        private

        def push_synchronously
          status = Rosette::DataStores::PhraseStatus::UNTRANSLATED
          datastore = rosette_config.datastore

          datastore.each_commit_log_with_status(repo_config.name, status) do |commit_log|
            push_commit(commit_log)
          end
        end

        def push_asynchronously
          pool = Concurrent::FixedThreadPool.new(thread_pool_size)
          status = Rosette::DataStores::PhraseStatus::UNTRANSLATED
          datastore = rosette_config.datastore

          untrans_count = rosette_config.datastore.commit_log_with_status_count(
            repo_config.name, status
          )

          datastore.each_commit_log_with_status(repo_config.name, status) do |commit_log|
            pool << Proc.new { push_commit(commit_log) }
          end

          drain_pool(pool, untrans_count)
        end

        def drain_pool(pool, total)
          pool.shutdown
          last_completed_count = 0

          while pool.shuttingdown?
            current_completed_count = pool.completed_task_count

            if current_completed_count > last_completed_count
              logger.info("#{repo_config.name}: #{current_completed_count} of #{total} pushed")
            end

            last_completed_count = current_completed_count
          end
        end

        def push_commit(commit_log)
          commit_id = commit_log.commit_id
          phrases = phrases_for(commit_id)

          if phrases.size > 0
            file_name = file_name_for(commit_id)
            uploader = build_uploader_for(
              phrases, file_name, serializer_id
            )

            response = uploader.upload
            commit_log.phrase_count = response['stringCount']
          end

          commit_log.push
          save_log(commit_log)
        rescue Java::OrgEclipseJgitErrors::MissingObjectException => ex
          commit_log.missing
          save_log(commit_log)

          rosette_config.error_reporter.report_warning(ex, {
            commit_id: commit_id
          })
        rescue => ex
          rosette_config.error_reporter.report_error(ex, {
            commit_id: commit_id
          })
        end

        def save_log(commit_log)
          rosette_config.datastore.add_or_update_commit_log(
            repo_config.name, commit_log.commit_id, nil,
            commit_log.status, commit_log.phrase_count
          )
        end

        def file_name_for(commit_id)
          rev_commit = repo_config.repo.get_rev_commit(commit_id)

          File.join(
            get_identity_string(rev_commit), commit_id
          )
        end

        def build_uploader_for(phrases, file_name, serializer_id)
          SmartlingIntegration::SmartlingUploader.new(rosette_config)
            .set_repo_config(repo_config)
            .set_phrases(phrases)
            .set_file_name(file_name)
            .set_serializer_id(serializer_id)
        end

        def phrases_for(commit_id)
          diff = Rosette::Core::Commands::ShowCommand.new(rosette_config)
            .set_repo_name(repo_config.name)
            .set_commit_id(commit_id)
            .execute

          (diff[:added] + diff[:modified]).map(&:phrase)
        end

        def get_identity_string(rev_commit)
          author_ident = rev_commit.getAuthorIdent
          name = get_identity_string_from_name(author_ident) ||
            get_identity_string_from_email(author_ident) ||
            'unknown'
        end

        def get_identity_string_from_name(author_ident)
          if name = author_ident.getName
            name.gsub(/[^\w]/, '')
          end
        end

        def get_identity_string_from_email(author_ident)
          if email = author_ident.getEmailAddress
            index = email.index('@') || 0
            email[0..index - 1].gsub(/[^\w]/, '')
          end
        end

      end
    end
  end
end

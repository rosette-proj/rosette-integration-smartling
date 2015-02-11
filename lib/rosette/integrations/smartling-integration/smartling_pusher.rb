# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class SmartlingPusher

        attr_reader :rosette_config, :repo_config

        def initialize(rosette_config)
          @rosette_config = rosette_config
        end

        def set_repo_config(repo_config)
          @repo_config = repo_config
          self
        end

        def push(commit_id, serializer_id)
          phrases = phrases_for(commit_id)

          if phrases.size > 0
            file_name = file_name_for(commit_id)
            uploader = build_uploader_for(
              phrases, file_name, serializer_id
            )

            response = uploader.upload
            phrase_count = response['stringCount']
          end

          rosette_config.datastore.add_or_update_commit_log(
            repo_config.name, commit_id, nil,
            Rosette::DataStores::PhraseStatus::PENDING, phrase_count
          )
        rescue => ex
          rosette_config.error_reporter.report_error(ex)
        end

        private

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

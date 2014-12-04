# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class SmartlingPusher
        attr_reader :rosette_config, :integration_config, :repo_name, :smartling_api

        def initialize(rosette_config, integration_config, repo_name, smartling_api)
          @smartling_api = smartling_api
          @integration_config = integration_config
          @rosette_config = rosette_config
          @repo_name = repo_name
        end

        def push(commit_id, serializer_id)
          destination_filenames(commit_id).map do |destination|
            file_for_upload(commit_id, serializer_id) do |tmp_file|
              response = smartling_api.upload(
                tmp_file.path, destination, 'YAML', approved: smartling_api.preapprove_translations?
              )
              phrase_count = response['stringCount']

              rosette_config.datastore.add_or_update_commit_log(
                repo_name, commit_id, nil, Rosette::DataStores::PhraseStatus::PENDING, phrase_count
              )
            end
          end
        rescue => ex
          Rosette.logger.error('Caught an exception while pushing to Smartling API.')
          Rosette.logger.error("#{ex.message}\n#{ex.backtrace.join("\n")}")
          raise ex
        end

        private

        def destination_filenames(commit_id)
          repo = rosette_config.get_repo(repo_name).repo
          rev_commit = repo.get_rev_commit(commit_id)

          [File.join(repo_name, get_identity_string(rev_commit), "#{commit_id}.yml")]
        end

        # @TODO: this will need to change if we inline phrases because
        # we might not have meta_keys anymore (this method assumes we do)
        def file_for_upload(commit_id, serializer_id)
          serializer_const = Rosette::Core::SerializerId.resolve(serializer_id)
          phrases = rosette_config.datastore.phrases_by_commit(repo_name, commit_id)

          if phrases.any?
            Tempfile.open(['rosette', serializer_const.default_extension]) do |file|
              file.write(integration_config.directives + "\n")

              serializer = serializer_const.new(file, rosette_config.get_repo(repo_name).source_locale)

              phrases.each do |phrase|
                serializer.write_key_value(phrase.index_value, phrase.key)
              end

              serializer.flush

              yield file
            end
          end
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

# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class SmartlingPusher
        FILE_TYPES =
          %w(android ios gettext html javaProperties yaml xliff xml json docx pptx xlsx idml qt resx plaintext)

        SERIALIZER_FILE_TYPE_MAP = {
          'xml/android' => 'android'
        }

        attr_reader :rosette_config, :integration_config, :repo_name, :smartling_api

        def initialize(rosette_config, integration_config, repo_name, smartling_api)
          @smartling_api = smartling_api
          @integration_config = integration_config
          @rosette_config = rosette_config
          @repo_name = repo_name
        end

        def push(commit_id, serializer_id)
          phrases_by_file = phrases_by_file_for(commit_id)
          serializer_const = Rosette::Core::SerializerId.resolve(serializer_id)

          phrases_by_file.each_pair do |file, phrases_for_file|
            dest_filename = destination_filename_for(file, phrases_for_file, serializer_const)

            file_for_upload(phrases_for_file, serializer_const) do |tmp_file|
              response = smartling_api.upload(
                tmp_file.path,
                dest_filename,
                file_type_for(serializer_id), {
                  approved: smartling_api.preapprove_translations?
                }
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

        def phrases_by_file_for(commit_id)
          Rosette::Core::Commands::SnapshotCommand.new(rosette_config)
            .set_repo_name(repo_name)
            .set_commit_id(commit_id)
            .execute
            .group_by(&:file)
        end

        # For serializer ids like yaml/rails and json/key-value, the
        # file type can be inferred from the first half (i.e. 'yaml'
        # and 'json'). For ambiguous file types like android xml, we
        # make use of SERIALIZER_FILE_TYPE_MAP which directly maps
        # serializer ids to file types.
        def file_type_for(serializer_id)
          if type = SERIALIZER_FILE_TYPE_MAP[serializer_id]
            type
          else
            id_parts = Rosette::Core::SerializerId.parse_id(serializer_id)
            id_parts.find do |id_part|
              FILE_TYPES.include?(id_part)
            end
          end
        end

        def destination_filename_for(file, phrases_for_file, serializer_const)
          unless phrases_for_file.empty?
            repo = rosette_config.get_repo(repo_name).repo
            commit_id = phrases_for_file.first.commit_id
            rev_commit = repo.get_rev_commit(commit_id)

            File.join(
              repo_name,
              get_identity_string(rev_commit),
              commit_id,
              "#{sanitize_path(file)}#{serializer_const.default_extension}"
            )
          end
        end

        # @TODO: this will need to change if we inline phrases because
        # we might not have meta_keys anymore (this method assumes we do)
        def file_for_upload(phrases, serializer_const)
          unless phrases.empty?
            Tempfile.open(['rosette', serializer_const.default_extension]) do |file|
              serializer = serializer_const.new(file, rosette_config.get_repo(repo_name).source_locale)
              serializer.write_raw(integration_config.directives + "\n")

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

        def sanitize_path(path)
          path.gsub('/', '$')
        end

      end
    end
  end
end

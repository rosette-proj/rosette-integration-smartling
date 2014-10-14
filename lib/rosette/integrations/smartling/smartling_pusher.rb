# encoding: UTF-8

module Rosette
  module Integrations
    module Smartling
      class SmartlingPusher < SmartlingOperation

        def initialize(datastore, repo_name, api_options = {})
          super(api_options)
          @datastore = datastore
          @repo_name = repo_name
        end

        def push(commit_id, serializer_id)
          destination_filenames(commit_id).map do |destination|
            file_for_upload(commit_id, serializer_id) do |tmp_file, phrase_count|
              api.upload(tmp_file.path, destination, 'YAML', approved: preapprove_translations?)
            end
          end
        rescue => ex
          Rosette.logger.error('Caught an exception while pushing to Smartling API.')
          Rosette.logger.error("#{ex.message}\n#{ex.backtrace.join("\n")}")
          raise ex
        end

        private

        def destination_filenames(commit_id)
          [File.join(repo_name, "#{commit_id}.yml")]
        end

        # @TODO: this will need to change if we inline phrases because
        # we might not have meta_keys anymore (this method assumes we do)
        def file_for_upload(commit_id, serializer_id)
          serializer_const = Rosette::Core::SerializerId.resolve(serializer_id)

          Tempfile.open(['rosette', serializer_const.default_extension]) do |file|
            serializer = serializer_const.new(file)
            phrases = datastore.phrases_by_commit(repo_name, commit_id)
            phrase_count = 0

            phrases.each do |phrase|
              serializer.write_key_value(phrase.index_value, phrase.key)
              phrase_count += 1
            end

            serializer.flush

            yield file, phrase_count
          end
        end

      end
    end
  end
end

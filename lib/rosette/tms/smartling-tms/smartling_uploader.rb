# encoding: UTF-8

module Rosette
  module Tms
    module SmartlingTms
      class SmartlingUploader

        FILE_TYPES =
          %w(android ios gettext html javaProperties yaml xliff xml json) +
          %w(docx pptx xlsx idml qt resx plaintext)

        SERIALIZER_FILE_TYPE_MAP = {
          'xml/android' => 'android'
        }

        attr_reader :configurator, :phrases, :file_uri

        def initialize(configurator)
          @configurator = configurator
        end

        def set_phrases(phrases)
          @phrases = phrases
          self
        end

        def set_file_uri(file_uri)
          @file_uri = file_uri
          self
        end

        def upload
          retrier = Retrier.retry(times: 9, base_sleep_seconds: 2) do
            file_for_upload do |tmp_file|
              smartling_api.upload(
                tmp_file.path, file_uri, file_type, {
                  approved: smartling_api.preapprove_translations?
                }
              )
            end
          end

          retrier
            .on_error(RuntimeError, message: /RESOURCE_LOCKED/, backoff: true)
            .on_error(RuntimeError, message: /VALIDATION_ERROR/, backoff: true)
            .on_error(Exception)
            .execute
        end

        private

        # For serializer ids like yaml/rails and json/key-value, the
        # file type can be inferred from the first half (i.e. 'yaml'
        # and 'json'). For ambiguous file types like android xml, we
        # make use of SERIALIZER_FILE_TYPE_MAP which directly maps
        # serializer ids to file types.
        def file_type
          @file_type ||= if type = SERIALIZER_FILE_TYPE_MAP[serializer_id]
            type
          else
            id_parts = Rosette::Core::SerializerId.parse_id(serializer_id)
            id_parts.find do |id_part|
              FILE_TYPES.include?(id_part)
            end
          end
        end

        # @TODO: this will need to change if we inline phrases because
        # we might not have meta_keys anymore (this method assumes we do)
        def file_for_upload
          Tempfile.open(['rosette', serializer_const.default_extension]) do |file|
            serializer = serializer_const.new(file, repo_config.source_locale)
            serializer.write_raw((directives || '') + "\n")

            write_phrases(serializer)
            serializer.flush

            yield file
          end
        end

        def write_phrases(serializer)
          if phrases.is_a?(Hash)
            write_phrase_hash(serializer)
          else
            write_phrase_array(serializer)
          end
        end

        def write_phrase_hash(serializer)
          phrases.each do |key, val|
            serializer.write_key_value(key, val)
          end
        end

        def write_phrase_array(serializer)
          phrases.each do |phrase|
            serializer.write_key_value(phrase.index_value, phrase.key)
          end
        end

        def serializer_const
          @serializer_const ||= Rosette::Core::SerializerId.resolve(serializer_id)
        end

        def directives
          configurator.directives
        end

        def serializer_id
          configurator.serializer_id
        end

        def repo_config
          configurator.repo_config
        end

        def smartling_api
          configurator.smartling_api
        end

      end
    end
  end
end

# encoding: UTF-8

module Rosette
  module Tms
    module SmartlingTms

      class SmartlingFile
        attr_reader :configurator, :commit_id, :statuses

        def initialize(configurator, commit_id)
          @configurator = configurator
          @commit_id = commit_id
        end

        def phrase_count
          if locale_statuses.size > 0
            locale_statuses.first.last.phrase_count
          else
            0
          end
        end

        def file_uri
          rev_commit = repo_config.repo.get_rev_commit(commit_id)

          File.join(
            repo_config.name,
            get_identity_string(rev_commit),
            "#{commit_id}#{serializer_const.default_extension}"
          )
        end

        def download(locale)
          SmartlingDownloader.download_file(
            smartling_api, file_uri, locale
          )
        end

        def upload(phrases)
          SmartlingUploader.new(configurator)
            .set_phrases(phrases)
            .set_file_uri(file_uri)
            .upload
        end

        def delete
          Retrier.retry(times: 3) do
            smartling_api.delete(file_uri)
          end.on_error(Exception).execute
        end

        def translation_status
          Rosette::Core::TranslationStatus.new(phrase_count).tap do |status|
            locale_statuses.each do |locale_code, locale_status|
              status.add_locale_count(locale_code, locale_status.translated_count)
            end
          end
        end

        protected

        def locale_statuses
          @statuses ||= repo_config.locales.each_with_object({}) do |locale, ret|
            ret[locale.code] = SmartlingLocaleStatus.from_api_response(
              fetch_status(locale)
            )
          end
        end

        def fetch_status(locale)
          retrier = Retrier.retry(times: 9, base_sleep_seconds: 2) do
            smartling_api.status(file_uri, locale: locale.code)
          end

          retrier
            .on_error(RuntimeError, message: /RESOURCE_LOCKED/, backoff: true)
            .execute

        rescue RuntimeError => e
          if is_non_existent_file_error?(e)
            build_nil_status
          else
            raise e
          end
        end

        def build_nil_status
          {
            'fileUri' => file_uri,
            'stringCount' => 0,
            'completedStringCount' => 0
          }
        end

        def is_non_existent_file_error?(e)
          e.message.include?('VALIDATION_ERROR') &&
            e.message.include?('could not be found')
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

        def serializer_const
          @serializer_const ||= Rosette::Core::SerializerId.resolve(serializer_id)
        end

        def rosette_config
          configurator.rosette_config
        end

        def repo_config
          configurator.repo_config
        end

        def smartling_api
          configurator.smartling_api
        end

        def serializer_id
          configurator.serializer_id
        end
      end

    end
  end
end

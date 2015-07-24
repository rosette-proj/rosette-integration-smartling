# encoding: UTF-8

module Rosette
  module Tms
    module SmartlingTms

      class SmartlingLocaleStatus
        attr_reader :repo_name, :ref
        attr_reader :phrase_count, :translated_count, :file_uri

        def initialize(repo_name, ref, phrase_count, translated_count, file_uri)
          @repo_name = repo_name
          @ref = ref
          @phrase_count = phrase_count
          @translated_count = translated_count
          @file_uri = file_uri
        end

        def self.from_api_response(response)
          file_uri = response['fileUri']
          repo_name, author, *ref = file_uri.split('/')
          ref = ref.join('/')
          ref = ref.chomp(File.extname(ref))
          phrase_count = response['stringCount']
          translated_count = response['completedStringCount']

          new(
            repo_name, ref, phrase_count,
            translated_count, file_uri
          )
        end

        def self.list_from_api_response(response)
          response['fileList'].map do |file|
            from_api_response(file)
          end
        end

        def complete?
          translated_count >= phrase_count
        end
      end

    end
  end
end

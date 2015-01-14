# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class SmartlingFile

        attr_reader :repo_name, :commit_id, :file
        attr_reader :phrase_count, :translated_count, :file_uri

        def initialize(repo_name, commit_id, file, phrase_count, translated_count, file_uri)
          @repo_name = repo_name
          @commit_id = commit_id
          @file = file
          @phrase_count = phrase_count
          @translated_count = translated_count
          @file_uri = file_uri
        end

        def self.from_api_response(response)
          file_uri = response['fileUri']
          repo_name, author, commit_id, file = file_uri.split('/')
          file = decode_path(file.chomp(File.extname(file)))
          phrase_count = response['stringCount']
          translated_count = response['completedStringCount']

          new(
            repo_name, commit_id, file, phrase_count,
            translated_count, file_uri
          )
        end

        def self.encode_path(path)
          path.gsub('/', '$')
        end

        def self.decode_path(path)
          path.gsub('$', '/')
        end

        def self.list_from_api_response(response)
          response['fileList'].map do |file|
            from_api_response(file)
          end
        end

        def complete?
          phrase_count == translated_count
        end

      end
    end
  end
end

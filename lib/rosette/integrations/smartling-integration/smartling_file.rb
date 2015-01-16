# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class SmartlingFile

        attr_reader :repo_name, :commit_id
        attr_reader :phrase_count, :translated_count, :file_uri

        def initialize(repo_name, commit_id, phrase_count, translated_count, file_uri)
          @repo_name = repo_name
          @commit_id = commit_id
          @phrase_count = phrase_count
          @translated_count = translated_count
          @file_uri = file_uri
        end

        def self.from_api_response(response)
          file_uri = response['fileUri']
          repo_name, author, commit_id = file_uri.split('/')
          commit_id = commit_id.chomp(File.extname(commit_id)) if commit_id
          phrase_count = response['stringCount']
          translated_count = response['completedStringCount']

          new(
            repo_name, commit_id, phrase_count,
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

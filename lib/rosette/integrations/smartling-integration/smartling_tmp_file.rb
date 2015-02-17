# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class SmartlingTmpFile

        attr_reader :phrase_count, :translated_count, :file_uri

        def initialize(phrase_count, translated_count, file_uri)
          @phrase_count = phrase_count
          @translated_count = translated_count
          @file_uri = file_uri
        end

        def self.from_api_response(response)
          file_uri = response['fileUri']
          phrase_count = response['stringCount']
          translated_count = response['completedStringCount']
          new(phrase_count, translated_count, file_uri)
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

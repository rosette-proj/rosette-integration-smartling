# encoding: UTF-8

module Rosette
  module Integrations
    module Smartling
      class SmartlingFileList

        include Enumerable

        attr_reader :file_list

        def initialize(file_list)
          @file_list = file_list
        end

        def each(&block)
          file_list.each(&block)
        end

        def self.from_api_response(response)
          new(
            response['fileList'].map do |file|
              SmartlingFile.from_api_response(file)
            end
          )
        end

      end
    end
  end
end

# encoding: UTF-8

module Rosette
  module Integrations
    module Smartling
      class SmartlingPuller < SmartlingOperation

        attr_reader :datastore

        def initialize(datastore, api_options = {})
          super(api_options)
          @datastore = datastore
        end

        def pull(locale)
          file_list_response = api.list(locale: locale)
          file_list = SmartlingFileList.from_api_response(file_list_response)

          file_list.each do |file|
            datastore.add_or_update_commit_log_locale(
              file.commit_id, locale, file.translated_count
            )
          end
        end

      end
    end
  end
end

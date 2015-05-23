# encoding: UTF-8

require 'smartling'
require 'rosette/integrations'

module Rosette
  module Tms

    module SmartlingTms
      autoload :SmartlingApi,                'rosette/tms/smartling-tms/smartling_api'
      autoload :SmartlingUploader,           'rosette/tms/smartling-tms/smartling_uploader'
      autoload :SmartlingDownloader,         'rosette/tms/smartling-tms/smartling_downloader'
      autoload :SmartlingFile,               'rosette/tms/smartling-tms/smartling_file'
      autoload :SmartlingLocaleStatus,       'rosette/tms/smartling-tms/smartling_locale_status'
      autoload :SmartlingTmxParser,          'rosette/tms/smartling-tms/smartling_tmx_parser'
      autoload :TranslationMemory,           'rosette/tms/smartling-tms/translation_memory'
      autoload :TranslationMemoryDownloader, 'rosette/tms/smartling-tms/translation_memory_downloader'
      autoload :Retrier,                     'rosette/tms/smartling-tms/retrier'
      autoload :Configurator,                'rosette/tms/smartling-tms/configurator'
      autoload :Repository,                  'rosette/tms/smartling-tms/repository'

      def self.configure(rosette_config, repo_config)
        configurator = Configurator.new(rosette_config, repo_config)
        yield configurator
        Repository.new(configurator)
      end

    end

  end
end

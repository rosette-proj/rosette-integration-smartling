# encoding: UTF-8

require 'smartling'
require 'rosette/integrations'

module Rosette
  module Integrations

    class SmartlingIntegration < Integration
      autoload :SmartlingApi,             'rosette/integrations/smartling-integration/smartling_api'
      autoload :SmartlingPusher,          'rosette/integrations/smartling-integration/smartling_puller'
      autoload :SmartlingPuller,          'rosette/integrations/smartling-integration/smartling_pusher'
      autoload :SmartlingUploader,        'rosette/integrations/smartling-integration/smartling_uploader'
      autoload :SmartlingDownloader,      'rosette/integrations/smartling-integration/smartling_downloader'
      autoload :SmartlingCompleter,       'rosette/integrations/smartling-integration/smartling_completer'
      autoload :SmartlingFile,            'rosette/integrations/smartling-integration/smartling_file'
      autoload :TranslationMemory,        'rosette/integrations/smartling-integration/translation_memory'
      autoload :TranslationMemoryBuilder, 'rosette/integrations/smartling-integration/translation_memory_builder'
      autoload :Retrier,                  'rosette/integrations/smartling-integration/retrier'
      autoload :Configurator,             'rosette/integrations/smartling-integration/configurator'

      def self.configure
        config = Configurator.new
        yield config if block_given?
        new(config)
      end

      def integrate(obj)
        unless integrates_with?(obj)
          raise Errors::ImpossibleIntegrationError,
            "Cannot integrate #{self.class.name} with #{obj}"
        end
      end

      def integrates_with?(obj)
        obj.is_a?(Rosette::Core::RepoConfig)
      end

      def smartling_api
        @smartling_api ||=
          SmartlingApi.new(configuration.api_options)
      end
    end

  end
end

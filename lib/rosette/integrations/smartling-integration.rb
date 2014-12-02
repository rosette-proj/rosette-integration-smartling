# encoding: UTF-8

require 'smartling'
require 'rosette/integrations'
require 'rosette/integrations/smartling-integration/errors'

module Rosette
  module Integrations

    class SmartlingIntegration < Integration
      autoload :SmartlingApi,       'rosette/integrations/smartling-integration/smartling_api'
      autoload :SmartlingPusher,    'rosette/integrations/smartling-integration/smartling_puller'
      autoload :SmartlingPuller,    'rosette/integrations/smartling-integration/smartling_pusher'
      autoload :SmartlingCompleter, 'rosette/integrations/smartling-integration/smartling_completer'

      autoload :SmartlingFile,      'rosette/integrations/smartling-integration/smartling_file'
      autoload :SmartlingFileList,  'rosette/integrations/smartling-integration/smartling_file_list'

      autoload :Configurator,       'rosette/integrations/smartling-integration/configurator'

      def self.configure
        config = Configurator.new
        yield config if block_given?
        new(config)
      end

      def integrate(obj)
        if integrates_with?(obj)
          integrate_with_repo_config(obj)
        else
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

      private

      def integrate_with_repo_config(obj)
        obj.after(:commit) do |rosette_config, repo_config, commit_id|
          smartling_pusher(rosette_config, repo_config.name).push(
            commit_id, configuration.serializer_id
          )
        end
      end

      def smartling_pusher(rosette_config, repo_name)
        smartling_pushers[repo_name] ||= SmartlingPusher.new(
          rosette_config, config, repo_name, smartling_api
        )
      end

      def smartling_pushers
        @smartling_pushers ||= {}
      end
    end

  end
end

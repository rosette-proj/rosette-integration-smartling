# encoding: UTF-8

require 'smartling'
require 'rosette/integrations'

module Rosette
  module Integrations

    class SmartlingIntegration < Integration
      autoload :SmartlingApi,       'rosette/integrations/smartling-integration/smartling_api'
      autoload :SmartlingPusher,    'rosette/integrations/smartling-integration/smartling_puller'
      autoload :SmartlingPuller,    'rosette/integrations/smartling-integration/smartling_pusher'
      autoload :SmartlingUploader,  'rosette/integrations/smartling-integration/smartling_uploader'
      autoload :SmartlingCompleter, 'rosette/integrations/smartling-integration/smartling_completer'
      autoload :SmartlingFile,      'rosette/integrations/smartling-integration/smartling_file'
      autoload :Retrier,            'rosette/integrations/smartling-integration/retrier'
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
        repo_config = rosette_config.get_repo(repo_name)
        smartling_pushers[repo_name] ||= SmartlingPusher.new(rosette_config)
          .set_repo_config(repo_config)
      end

      def smartling_pushers
        @smartling_pushers ||= {}
      end
    end

  end
end

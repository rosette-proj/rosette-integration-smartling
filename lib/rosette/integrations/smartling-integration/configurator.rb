# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration

      class Configurator
        attr_reader :api_options, :serializer_id

        def initialize
          @api_options = {}
          @serializer_id = :serializer_not_configured
        end

        def set_api_options(options)
          @api_options = options
        end

        def set_serializer(serializer_id)
          @serializer_id = serializer_id
        end
      end

    end
  end
end

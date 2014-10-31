# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      module Errors

        class AmbiguousEncodingError < StandardError; end

      end
    end
  end
end

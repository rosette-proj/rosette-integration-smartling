# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration

      class Configurator
        attr_reader :api_options, :memory_api_options
        attr_reader :serializer_id, :directives

        def initialize
          @api_options = {}
          @serializer_id = :serializer_not_configured
          @directives = ''
        end

        # Options used to build a SmartlingApi that can communicate with the
        # Smartling project where all new/changed phrases should be uploaded
        # and downloaded. This is the main project translators and
        # administrators should interact with.
        def set_api_options(options)
          @api_options = options
        end

        # Options used to build a SmartlingApi that can communicate with a
        # separate Smartling project used only to manage the translation
        # memory. Rosette builds a translation memory on each pull from all
        # the unique key and meta key pairs that have ever existed for the given
        # project. When this file gets uploaded to Smartling, it can really
        # muddy up Smartling's "To Authorize" view. To keep the waters clear,
        # you can specify a second set of options with this method that point
        # to a separate Smartling project that shares a Smartling smart match-
        # enabled translation memory (distinct from the one we build).
        def set_memory_api_options(options)
          @memory_api_options = options
        end

        def set_directives(directives)
          @directives = directives
        end

        def set_serializer(serializer_id)
          @serializer_id = serializer_id
        end
      end

    end
  end
end

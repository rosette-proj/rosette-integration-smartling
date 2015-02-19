# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class TranslationMemory

        DEFAULT_HASH = {}.freeze

        def initialize(translation_hash)
          @translation_hash = translation_hash
        end

        def translation_for(locale, meta_key)
          all_for_locale = @translation_hash.fetch(locale.code, DEFAULT_HASH)

          if translation = all_for_locale[meta_key]
            translation.key
          end
        end

      end
    end
  end
end

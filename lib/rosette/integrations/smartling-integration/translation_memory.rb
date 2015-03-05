# encoding: UTF-8

require 'digest/sha1'

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class TranslationMemory

        DEFAULT_HASH = {}.freeze

        def initialize(translation_hash)
          @translation_hash = translation_hash
        end

        def translation_for(locale, meta_key)
          all_for_locale = translations_for(locale)

          if translation = all_for_locale[meta_key]
            translation.key
          end
        end

        def checksum_for(locale)
          checksums.fetch(locale.code) do
            digest = Digest::SHA1.new
            translations = translations_for(locale)

            translations.keys.sort.each do |meta_key|
              digest << meta_key
              digest << translations[meta_key].key
            end

            digest.hexdigest
          end
        end

        private

        def translations_for(locale)
          @translation_hash.fetch(locale.code, DEFAULT_HASH)
        end

        def checksums
          @checksums ||= {}
        end

      end
    end
  end
end

# encoding: UTF-8

require 'digest/sha1'
require 'thread'

module Rosette
  module Integrations
    class SmartlingIntegration < Integration

      class PlaceholderMismatchError < StandardError; end

      class TranslationMemory

        DEFAULT_HASH = {}.freeze
        PLURAL_REGEX = /\.?(zero|one|two|few|many|other)\z/

        attr_reader :translation_hash, :repo_config

        def initialize(translation_hash, repo_config)
          @translation_hash = translation_hash
          @repo_config = repo_config
          @checksum_mutex = Mutex.new
        end

        def translation_for(locale, phrase)
          if is_potential_plural?(phrase.meta_key)
            unit = find_plural_translation_for(locale, phrase.meta_key)
          end

          unit ||= all_translations_for(locale)
            .fetch(phrase.meta_key, {})
            .first

          resolve(unit, locale, phrase) if unit
        end

        def checksum_for(locale)
          @checksum_mutex.synchronize do
            checksums.fetch(locale.code) do
              digest = Digest::SHA1.new
              digest_locale(locale, digest)
              checksums[locale.code] = digest.hexdigest
            end
          end
        end

        private

        # resolves placeholders and paired tags, returns a string
        def resolve(unit, locale, phrase)
          if variant = find_variant(unit, locale)
            placeholders = associate_placeholders(variant, phrase)

            variant.elements.each_with_object('') do |el, ret|
              ret << case el
                when String
                  el
                when TmxParser::Placeholder
                  placeholders[el.text]
                else
                  el.text
              end
            end
          end
        end

        def digest_locale(locale, digest)
          translations = all_translations_for(locale)

          translations.keys.sort.each do |meta_key|
            digest_string(meta_key, digest)

            translations[meta_key].each do |unit|
              digest_unit(unit, locale, digest)
            end
          end
        end

        def digest_string(string, digest)
          digest << string
        end

        def digest_unit(unit, locale, digest)
          if variant = find_variant(unit, locale)
            variant.elements.each do |element|
              digest << case element
                when String
                  element
                else
                  element.text
              end
            end
          end
        end

        def find_variant(unit, locale)
          unit.variants.find do |variant|
            variant.locale == locale.code
          end
        end

        def is_potential_plural?(meta_key)
          !!(meta_key =~ PLURAL_REGEX)
        end

        def find_plural_translation_for(locale, meta_key)
          all_translations = all_translations_for(locale)
          meta_key_base = meta_key.sub(PLURAL_REGEX, '')
          plural_form = $1

          if units = all_translations[meta_key_base]
            plural_form_suffix = "[#{plural_form}]"

            units.find do |unit|
              unit.tuid.end_with?(plural_form_suffix)
            end
          end
        end

        def placeholder_regex
          @placeholder_regex ||= Regexp.union(
            repo_config.placeholder_regexes
          )
        end

        def associate_placeholders(variant, phrase)
          named_placeholders = phrase.key.scan(placeholder_regex)
          smartling_placeholders = variant.elements.each_with_object([]) do |el, ret|
            ret << el.text if el.is_a?(TmxParser::Placeholder)
          end

          if named_placeholders.size != smartling_placeholders.size
            raise PlaceholderMismatchError,
              "Found #{named_placeholders.size} placeholder(s) in original key but " +
                "the same string in the translation memory has " +
                "#{smartling_placeholders.size} placeholder(s). Variant is " +
                "#{phrase.meta_key}."
          end

          Hash[smartling_placeholders.zip(named_placeholders)]
        end

        def all_translations_for(locale)
          @translation_hash.fetch(locale.code, DEFAULT_HASH)
        end

        def checksums
          @checksums ||= {}
        end

      end
    end
  end
end

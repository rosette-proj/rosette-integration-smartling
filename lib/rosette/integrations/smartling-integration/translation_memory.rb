# encoding: UTF-8

require 'twitter_cldr'
require 'digest/sha1'
require 'thread'

module Rosette
  module Integrations
    class SmartlingIntegration < Integration

      class TranslationMemory
        DEFAULT_HASH = {}.freeze
        PLURAL_REGEX = /\.?(zero|one|two|few|many|other)\z/
        ALLOW_FUZZY = true

        attr_reader :translation_hash, :rosette_config, :repo_config

        def initialize(translation_hash, rosette_config, repo_config)
          @translation_hash = translation_hash
          @rosette_config = rosette_config
          @repo_config = repo_config
          @checksum_mutex = Mutex.new
        end

        def translation_for(locale, phrase)
          translation_cache[phrase.meta_key + phrase.key] ||= begin
            if is_potential_plural?(phrase.meta_key)
              units = find_plural_translation_for(locale, phrase.meta_key)
            end

            if !units || units.empty?
              units = all_translations_for(locale).fetch(phrase.meta_key, [])
            end

            resolve(units, locale, phrase)
          end
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

        def translation_cache
          @translation_cache ||= {}
        end

        # resolves placeholders and paired tags, returns a string
        def resolve(units, locale, phrase)
          source_placeholders = source_placeholders_for(phrase)

          unit = units.find do |unit|
            can_resolve?(unit, locale, phrase, source_placeholders)
          end

          # If no unit can be found via an exact match, return the first one
          # in the list. We know the meta key matches, but it's possible the
          # key has changed.
          unit ||= units.first if ALLOW_FUZZY

          if unit && variant = find_variant(unit, locale)
            resolve_variant(variant, source_placeholders)
          end
        end

        def can_resolve?(unit, locale, phrase, source_placeholders)
          if variant = find_variant(unit, repo_config.source_locale)
            normalized_eql?(
              phrase.key,
              resolve_variant(variant, source_placeholders)
            )
          else
            false
          end
        end

        def normalized_eql?(str1, str2)
          smartling_normalize(TwitterCldr::Normalization.normalize(str1)).eql?(
            smartling_normalize(TwitterCldr::Normalization.normalize(str2))
          )
        end

        def smartling_normalize(str)
          str.gsub("\r", "\n").strip
        end

        def resolve_variant(variant, source_placeholders)
          target_placeholders = target_placeholders_for(variant)
          placeholders = associate_placeholders(
            target_placeholders, source_placeholders
          )

          if placeholders.size > 0
            resolve_with_placeholders(variant, placeholders)
          else
            resolve_without_placeholders(variant)
          end
        end

        def source_placeholders_for(phrase)
          phrase.key.scan(placeholder_regex)
        end

        def target_placeholders_for(variant)
          variant.elements.each_with_object([]) do |el, ret|
            case el
              when TmxParser::Placeholder
                ret << el.text
              else
                str = el.respond_to?(:text) ? el.text : el
                ret.concat(find_inline_placeholders(str))
            end
          end
        end

        def associate_placeholders(target_placeholders, source_placeholders)
          Hash[target_placeholders.zip(source_placeholders)]
        end

        def resolve_with_placeholders(variant, placeholders)
          variant.elements.each_with_object('') do |el, ret|
            ret << case el
              when TmxParser::Placeholder
                placeholders[el.text] || ''
              else
                str = el.respond_to?(:text) ? el.text : el

                if str
                  str.dup.tap do |text|
                    placeholders.each do |source, target|
                      text.sub!(source, target) if source && target
                    end
                  end
                else
                  ''
                end
            end
          end
        end

        def resolve_without_placeholders(variant)
          variant.elements.each_with_object('') do |el, ret|
            ret << (el.respond_to?(:text) ? el.text : el)
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
          variants = unit.variants.sort { |v1, v2| v1.locale <=> v2.locale }
          variants.each do |variant|
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
            variant.locale == locale.code || variant.locale == locale.language
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

            units.select do |unit|
              unit.tuid.end_with?(plural_form_suffix)
            end
          end
        end

        def placeholder_regex
          @placeholder_regex ||= Regexp.union(
            repo_config.placeholder_regexes
          )
        end

        def find_inline_placeholders(text)
          text.scan(inline_placeholder_regex)
        end

        def inline_placeholder_regex
          @inline_placeholder_regex ||= Regexp.union(
            /\{ph:\\?\{\d+\\?\}\}/, placeholder_regex
          )
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

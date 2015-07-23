# encoding: UTF-8

require 'twitter_cldr'
require 'digest/sha1'
require 'thread'

module Rosette
  module Tms
    module SmartlingTms

      class TranslationMemory
        DEFAULT_HASH = {}.freeze
        PLURAL_REGEX = /\.?(zero|one|two|few|many|other)\z/
        PLACEHOLDER_TYPE = 'x-smartling-placeholder'
        WHITESPACE_REGEX = TwitterCldr::Shared::UnicodeRegex.compile(
          # space separators, line separators, paragraph separators, control characters
          # https://en.wikipedia.org/wiki/Unicode_character_property#General_Category
          '[[:Zs:][:Zl:][:Zp:][:Cc:]]+'
        ).to_regexp

        attr_reader :translation_hash, :configurator

        def initialize(translation_hash, configurator)
          @translation_hash = translation_hash
          @configurator = configurator
          @checksum_mutex = Mutex.new
          @cache_mutex = Mutex.new
        end

        def translation_for(locale, phrase)
          fetch(locale, phrase) do
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

        def fetch(locale, phrase)
          key = "#{locale.code}#{phrase.meta_key}#{phrase.key}"
          translation_cache.fetch(key) do
            @cache_mutex.synchronize do
              translation_cache[key] = yield
            end
          end
        end

        def translation_cache
          @translation_cache ||= {}
        end

        # resolves placeholders and paired tags, returns a string
        def resolve(units, locale, phrase)
          unit_candidates = resolve_exact(units, locale, phrase)

          if unit_candidates.empty?
            unit_candidates = resolve_ignoring_whitespace(
              units, locale, phrase
            )
          end

          # try to get the most recent one
          unit = unit_candidates.last

          if unit && variant = find_variant(unit, locale)
            placeholder_map = build_placeholder_map(phrase, unit)
            resolve_variant(variant, placeholder_map)
          else
            # If no matching unit can be found, return the original English string
            phrase.key
          end
        end

        def resolve_exact(units, locale, phrase)
          units.select do |unit|
            can_resolve?(unit, locale, phrase)
          end
        end

        def resolve_ignoring_whitespace(units, locale, phrase)
          units.select do |unit|
            can_resolve?(unit, locale, phrase, true)
          end
        end

        def can_resolve?(unit, locale, phrase, ignore_whitespace = false)
          placeholder_map = build_placeholder_map(phrase, unit)

          if variant = find_variant(unit, repo_config.source_locale)
            normalized_eql?(
              phrase.key, resolve_variant(variant, placeholder_map),
              ignore_whitespace
            )
          else
            false
          end
        end

        def normalized_eql?(str1, str2, ignore_whitespace = false)
          norm_str1 = smartling_normalize(cldr_normalize(str1))
          norm_str2 = smartling_normalize(cldr_normalize(str2))

          if ignore_whitespace
            strip_whitespace(norm_str1).eql?(strip_whitespace(norm_str2))
          else
            norm_str1.eql?(norm_str2)
          end
        end

        def strip_whitespace(str)
          str.gsub(WHITESPACE_REGEX, '')
        end

        def cldr_normalize(str)
          TwitterCldr::Normalization.normalize(str)
        end

        def smartling_normalize(str, ignore_whitespace = false)
          str.gsub("\r", "\n").strip
        end

        def resolve_variant(variant, placeholder_map)
          if placeholder_map.size > 0
            resolve_with_placeholders(variant, placeholder_map)
          else
            resolve_without_placeholders(variant)
          end
        end

        def build_placeholder_map(phrase, unit)
          target_variant = find_variant(unit, repo_config.source_locale)
          target_placeholders = variant_placeholders_for(target_variant)
          source_placeholders = phrase_placeholders_for(phrase)
          associate_placeholders(target_placeholders, source_placeholders)
        end

        def phrase_placeholders_for(phrase)
          phrase.key.scan(placeholder_regex)
        end

        def variant_placeholders_for(variant)
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

        def resolve_with_placeholders(variant, placeholder_map)
          variant.elements.each_with_object('') do |el, ret|
            ret << case el
              when TmxParser::Placeholder
                if el.type == PLACEHOLDER_TYPE
                  # if placeholder can't be found, replace with original text
                  placeholder_map[el.text] || el.text
                else
                  el.text
                end
              else
                str = el.respond_to?(:text) ? el.text : el

                if str
                  str.dup.tap do |text|
                    placeholder_map.each_pair do |source, target|
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

          # $1 holds the plural form (eg. 'one', 'many', 'other', etc)
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

        def repo_config
          configurator.repo_config
        end

      end

    end
  end
end

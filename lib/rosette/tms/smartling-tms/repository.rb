# encoding: UTF-8

require 'rosette/tms'
require 'thread'

module Rosette
  module Tms
    module SmartlingTms

      class Repository < Rosette::Tms::Repository
        attr_reader :configurator

        def initialize(configurator)
          @configurator = configurator
          @refresh_mutex = Mutex.new
        end

        def lookup_translations(locale, phrases)
          Array(phrases).map do |phrase|
            memory.translation_for(locale, phrase)
          end
        end

        def lookup_translation(locale, phrase)
          lookup_translations(locale, [phrase]).first
        end

        def store_phrases(phrases, commit_id)
          file = SmartlingFile.new(configurator, commit_id)
          file.upload(phrases)
        end

        def store_phrase(phrase, commit_id)
          store_phrases([phrase], commit_id)
        end

        def checksum_for(locale, commit_id)
          memory.checksum_for(locale)
        end

        def status(commit_id)
          file = SmartlingFile.new(configurator, commit_id)
          file.translation_status
        end

        def finalize(commit_id)
          file = SmartlingFile.new(configurator, commit_id)
          file.delete
        end

        protected

        def memory
          refresh_memory
          @memory
        end

        def refresh_memory
          fetch_options = { expires_in: configurator.pull_expiration }

          memory_hash = rosette_config.cache.fetch(cache_key, fetch_options) do
            download_memory.tap do |memory_hash|
              @memory = parse_memory_hash(memory_hash)
            end
          end

          @refresh_mutex.synchronize do
            # just in case the cache was already warm
            @memory ||= parse_memory_hash(memory_hash)
          end
        end

        def parse_memory_hash(memory_hash)
          parsed = memory_hash.each_with_object({}) do |(locale, raw_tmx), ret|
            ret[locale] = SmartlingTmxParser.load(raw_tmx)
          end

          TranslationMemory.new(parsed, configurator)
        end

        def cache_key
          @cache_key ||=
            "rosette-tms-smartling/translation-memories/#{repo_config.name}"
        end

        def download_memory
          TranslationMemoryDownloader.new(configurator).build
        end

        def repo_config
          configurator.repo_config
        end

        def rosette_config
          configurator.rosette_config
        end
      end

    end
  end
end

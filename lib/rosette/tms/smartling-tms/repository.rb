# encoding: UTF-8

require 'rosette/tms'
require 'thread'

module Rosette
  module Tms
    module SmartlingTms

      class Repository < Rosette::Tms::Repository
        attr_reader :configurator, :last_parse_time

        def initialize(configurator)
          @configurator = configurator
          @refresh_mutex = Mutex.new
          @last_parse_time = 0
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

          if configurator.perform_deletions?
            file.delete
          else
            Rosette.logger.info(
              "Finalizing #{file.file_uri}, however rosette-tms-smartling is "\
                "configured to not delete files from Smartling. Call the "\
                "set_perform_deletions(boolean) method on the configurator to "\
                "change this behavior."
            )
          end
        end

        def re_download_memory
          @refresh_mutex.synchronize do
            rosette_config.cache.write(memory_hash_cache_key, download_memory)
            @last_parse_time = 0  # force a re-parse
          end
        end

        protected

        def memory
          @refresh_mutex.synchronize do
            refresh_memory
            @memory
          end
        end

        def refresh_memory
          if memory_requires_refresh?
            memory_hash = rosette_config.cache.fetch(memory_hash_cache_key) do
              download_memory  # just in case
            end

            @memory = parse_memory_hash(memory_hash)
            @last_parse_time = Time.now.to_i
          end
        end

        def memory_requires_refresh?
          @memory.nil? || (
            (Time.now.to_i - last_parse_time) > configurator.parse_frequency
          )
        end

        def parse_memory_hash(memory_hash)
          parsed = memory_hash.each_with_object({}) do |(locale, raw_tmx), ret|
            ret[locale] = SmartlingTmxParser.load(raw_tmx)
          end

          TranslationMemory.new(parsed, configurator)
        end

        def memory_hash_cache_key
          @memory_hash_cache_key ||=
            "rosette-tms-smartling/translation-memories/#{repo_config.name}/memory_hash"
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

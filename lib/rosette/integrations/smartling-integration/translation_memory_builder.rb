# encoding: UTF-8

require 'thread'
require 'concurrent'
require 'smartling/uri'
require 'restclient'

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class TranslationMemoryBuilder

        TMX_API_PATH = 'translations/download'
        DEFAULT_THREAD_POOL_SIZE = 10

        attr_reader :rosette_config, :repo_config, :thread_pool_size, :logger

        def initialize(rosette_config)
          @rosette_config = rosette_config
          @thread_pool_size = DEFAULT_THREAD_POOL_SIZE
          @logger = Rosette.logger
        end

        def set_repo_config(repo_config)
          @repo_config = repo_config
          self
        end

        def set_thread_pool_size(thread_pool_size)
          @thread_pool_size = thread_pool_size
          self
        end

        def set_logger(logger)
          @logger = logger
          self
        end

        def build
          memory = if thread_pool_size > 0
            build_asynchronously
          else
            build_synchronously
          end

          TranslationMemory.new(memory, repo_config)
        end

        private

        def build_synchronously
          repo_config.locales.each_with_object({}) do |locale, ret|
            ret[locale.code] = download_and_process(locale)
          end
        end

        def build_asynchronously
          pool = Concurrent::FixedThreadPool.new(thread_pool_size)
          hash_mutex ||= Mutex.new
          total = 0

          result = repo_config.locales.each_with_object({}) do |locale, ret|
            pool << Proc.new do
              memory_hash = download_and_process(locale)
              hash_mutex.synchronize { ret[locale.code] = memory_hash }
            end

            total += 1
          end

          drain_pool(pool, total)
          result
        end

        def drain_pool(pool, total)
          pool.shutdown
          last_completed_count = 0

          while pool.shuttingdown?
            current_completed_count = pool.completed_task_count

            if current_completed_count > last_completed_count
              logger.info("Downloading locale #{current_completed_count} of #{total}")
            end

            last_completed_count = current_completed_count
          end
        end

        def download_and_process(locale)
          SmartlingTmxParser.load(download(locale))
        end

        def download(locale)
          uri = smartling_api.api.uri(TMX_API_PATH, {
            locale: locale.code, format: 'TMX', dataSet: 'published'
          })

          RestClient.get(uri.to_s).body
          # File.read("/Users/cameron/Downloads/memories/#{locale.code}-published.tmx")
        end

        def smartling_api
          @smartling_api ||=
            repo_config.get_integration('smartling').smartling_api
        end

      end
    end
  end
end

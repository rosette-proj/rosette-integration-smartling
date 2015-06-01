# encoding: UTF-8

require 'thread'
require 'concurrent'
require 'smartling/uri'
require 'restclient'

module Rosette
  module Tms
    module SmartlingTms
      class TranslationMemoryDownloader

        TMX_API_PATH = 'translations/download'
        DEFAULT_THREAD_POOL_SIZE = 10

        attr_reader :configurator

        def initialize(configurator)
          @configurator = configurator
        end

        def build
          if configurator.thread_pool_size > 0
            build_asynchronously
          else
            build_synchronously
          end
        end

        private

        def build_synchronously
          repo_config.locales.each_with_object({}) do |locale, ret|
            ret[locale.code] = download(locale)
          end
        end

        def build_asynchronously
          pool = Concurrent::FixedThreadPool.new(configurator.thread_pool_size)
          hash_mutex = Mutex.new
          total = 0

          result = repo_config.locales.each_with_object({}) do |locale, ret|
            pool << Proc.new do
              raw_tmx = download(locale)
              hash_mutex.synchronize { ret[locale.code] = raw_tmx }
            end

            total += 1
          end

          drain_pool(pool, total)
          result
        end

        def drain_pool(pool, total)
          pool.shutdown
          sleep 0.5 while pool.shuttingdown?
        end

        def download(locale)
          uri = smartling_api.api.uri(TMX_API_PATH, {
            locale: locale.code, format: 'TMX', dataSet: 'published'
          })

          RestClient.get(uri.to_s).body
        end

        def smartling_api
          configurator.smartling_api
        end

        def repo_config
          configurator.repo_config
        end

      end
    end
  end
end

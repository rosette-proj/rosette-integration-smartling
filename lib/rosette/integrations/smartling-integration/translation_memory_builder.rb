# encoding: UTF-8

require 'concurrent'
require 'thread'

module Rosette
  module Integrations
    class SmartlingIntegration < Integration
      class TranslationMemoryBuilder

        DEFAULT_THREAD_POOL_SIZE = 10

        attr_reader :rosette_config, :repo_config
        attr_reader :serializer_id, :extractor_id
        attr_reader :uploader, :thread_pool_size
        attr_reader :logger

        def initialize(rosette_config)
          @rosette_config = rosette_config
          @thread_pool_size = DEFAULT_THREAD_POOL_SIZE
          @logger = Rosette.logger
        end

        def set_repo_config(repo_config)
          @repo_config = repo_config
          self
        end

        def set_serializer_id(serializer_id)
          @serializer_id = serializer_id
          self
        end

        def set_extractor_id(extractor_id)
          @extractor_id = extractor_id
          self
        end

        def set_thread_pool_size(size)
          @thread_pool_size = size
          self
        end

        def set_logger(logger)
          @logger = logger
          self
        end

        def build
          phrases = get_phrases
          @uploader = build_uploader_for(phrases)

          logger.info('Uploading translation memory seed to Smartling')
          uploader.upload

          TranslationMemory.new(
            download(repo_config.locales, uploader)
          )
        end

        # used?
        def cleanup
          if uploader
            delete_file(uploader.destination_file_uri)
          end
        end

        private

        def hash_mutex
          @hash_mutex ||= Mutex.new
        end

        def get_phrases
          if thread_pool_size > 0
            get_phrases_asynchronously
          else
            get_phrases_synchronously
          end
        end

        def get_phrases_synchronously
          datastore.each_unique_meta_key(repo_config.name).each_with_object({}) do |meta_key, ret|
            recent_key = datastore.most_recent_key_for_meta_key(
              repo_config.name, meta_key
            )

            ret[meta_key] = recent_key
          end
        end

        def get_phrases_asynchronously
          pool = Concurrent::FixedThreadPool.new(thread_pool_size)
          counter = 0

          phrases = datastore.each_unique_meta_key(repo_config.name).each_with_object({}) do |meta_key, ret|
            pool << Proc.new do
              recent_key = datastore.most_recent_key_for_meta_key(
                repo_config.name, meta_key
              )

              hash_mutex.synchronize do
                ret[meta_key] = recent_key
              end
            end

            counter += 1
          end

          drain_pool(pool) do |completed_count|
            logger.info(
              "#{repo_config.name}: #{completed_count} of #{counter} meta keys identified"
            )
          end

          phrases
        end

        def drain_pool(pool)
          pool.shutdown
          last_completed_count = 0

          while pool.shuttingdown?
            current_completed_count = pool.completed_task_count

            if current_completed_count > last_completed_count
              yield current_completed_count
            end

            last_completed_count = current_completed_count
          end
        end

        def delete_file(file_uri)
          Retrier.retry(times: 3) do
            smartling_api.delete(file_uri)
          end.on_error(Exception).execute
        end

        def download(locales, uploader)
          if thread_pool_size > 0
            download_asynchronously(locales, uploader)
          else
            download_synchronously(locales, uploader)
          end
        end

        def download_synchronously(locales, uploader)
          locales.each_with_object({}) do |locale, ret|
            contents = download_locale(locale, uploader)
            ret[locale.code] = extractor.extract_each_from(contents).each_with_object({}) do |(trans, _), ret|
              ret[trans.meta_key] = trans
            end
          end
        end

        def download_asynchronously(locales, uploader)
          pool = Concurrent::FixedThreadPool.new(thread_pool_size)

          result = locales.each_with_object({}) do |locale, ret|
            pool << Proc.new do
              contents = download_locale(locale, uploader)
              extracted = extractor.extract_each_from(contents).each_with_object({}) do |(trans, _), ret|
                ret[trans.meta_key] = trans
              end

              hash_mutex.synchronize do
                ret[locale.code] = extracted
              end
            end
          end

          drain_pool(pool) do |completed_count|
            logger.info(
              "#{repo_config.name}: #{completed_count} of #{locales.size} locales downloaded"
            )
          end

          result
        end

        def download_locale(locale, uploader)
          SmartlingDownloader.download_file(
            smartling_api, uploader.destination_file_uri, locale
          )
        end

        def build_uploader_for(phrases)
          SmartlingUploader.new(rosette_config)
            .set_repo_config(repo_config)
            .set_phrases(phrases)
            .set_file_name('memory')
            .set_serializer_id(serializer_id)
            .set_smartling_api(smartling_api)
        end

        def smartling_api
          repo_config.get_integration('smartling').smartling_memory_api
        end

        def datastore
          rosette_config.datastore
        end

        def extractor_config
          @extractor_config ||=
            repo_config.get_extractor_config(extractor_id)
        end

        def extractor
          @extractor ||= extractor_config.extractor
        end

      end
    end
  end
end

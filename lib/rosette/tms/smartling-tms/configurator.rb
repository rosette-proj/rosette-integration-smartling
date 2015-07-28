# encoding: UTF-8

module Rosette
  module Tms
    module SmartlingTms

      class Configurator
        PhraseStorageGranularity = Rosette::Queuing::Commits::PhraseStorageGranularity

        DEFAULT_PARSE_FREQUENCY = 3600  # one hour in seconds
        DEFAULT_THREAD_POOL_SIZE = 10
        DEFAULT_PHRASE_STORAGE_GRANULARITY = PhraseStorageGranularity::COMMIT

        attr_reader :rosette_config, :repo_config
        attr_reader :api_options, :serializer_id, :directives, :parse_frequency
        attr_reader :thread_pool_size, :phrase_storage_granularity
        attr_reader :perform_deletions

        alias_method :perform_deletions?, :perform_deletions

        def initialize(rosette_config, repo_config)
          @api_options = {}
          @serializer_id = :serializer_not_configured
          @directives = ''
          @rosette_config = rosette_config
          @repo_config = repo_config
          @thread_pool_size = DEFAULT_THREAD_POOL_SIZE
          @parse_frequency = DEFAULT_PARSE_FREQUENCY
          @phrase_storage_granularity = DEFAULT_PHRASE_STORAGE_GRANULARITY
          @perform_deletions = true
        end

        # Options used to build a SmartlingApi that can communicate with the
        # Smartling project where all new/changed phrases should be uploaded
        # and downloaded. This is the main project translators and
        # administrators should interact with.
        def set_api_options(options)
          @api_options = options
        end

        def set_directives(directives)
          @directives = directives
        end

        def set_serializer(serializer_id)
          @serializer_id = serializer_id
        end

        def set_parse_frequency(parse_frequency)
          @parse_frequency = parse_frequency
        end

        def set_thread_pool_size(thread_pool_size)
          @thread_pool_size = thread_pool_size
        end

        def set_phrase_storage_granularity(granularity)
          @phrase_storage_granularity = granularity
        end

        def set_perform_deletions(perform)
          @perform_deletions = perform
        end

        def smartling_api
          @smartling_api ||= SmartlingApi.new(api_options)
        end
      end

    end
  end
end

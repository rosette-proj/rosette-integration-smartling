# encoding: UTF-8

require 'nokogiri'

module Rosette
  module Integrations
    class SmartlingIntegration < Integration

      # To be used when parsing .tmx files using Nokogiri. It turns out to be
      # quite a bit faster to parse this way than parsing the whole document
      # and looking for individual elements with xpath. We do sacrifice a bit
      # of code readability, but the document really isn't that complicated.
      class TmxDocument < Nokogiri::XML::SAX::Document
        UNIT_TAG             = 'tu'
        TRANSLATION_UNIT_TAG = 'tuv'
        PROPERTY_TAG         = 'prop'
        SEGMENT_TAG          = 'seg'

        TUID_ATTR            = 'tuid'
        TYPE_ATTR            = 'type'
        LANG_ATTR            = 'xml:lang'
        SEGMENT_ID_ATTR      = 'x-segment-id'
        VARIANT_ATTR         = 'smartling_string_variant'

        class MissingTranslationUnitError < StandardError; end

        attr_reader :locale_code, :proc

        def initialize(locale_code, &block)
          @proc = block
          @locale_code = locale_code
          @capture_key = false
          @capture_prop = false
          @lang_found = false
          @props = {}
          @key = nil
        end

        def start_element(name, attrs = [])
          case name
            when UNIT_TAG
              @tuid = get_attr(TUID_ATTR, attrs)
            when PROPERTY_TAG
              @prop_type = get_attr(TYPE_ATTR, attrs)
              @capture_prop = true
            when TRANSLATION_UNIT_TAG
              @lang = get_attr(LANG_ATTR, attrs)
            when SEGMENT_TAG
              @capture_key = (@lang == locale_code)
              @lang_found = (@lang == locale_code)
          end
        end

        def end_element(name)
          case name
            when UNIT_TAG
              unless @lang_found
                raise MissingTranslationUnitError,
                  "Couldn't find an entry for #{locale_code} in one of the translation units."
              end

              if @props[SEGMENT_ID_ATTR] == '0' && @key
                meta_key = @props[VARIANT_ATTR]
                proc.call(meta_key || @tuid, @key)
                @props.clear
                @key = nil
                @lang_found = false
              end
          end
        end

        def characters(str)
          if @capture_key
            @key = str
            @capture_key = false
          elsif @capture_prop
            @props[@prop_type] = str
            @capture_prop = false
          end
        end

        private

        def get_attr(name, attrs)
          if found = attrs.find { |a| a.first == name }
            found.last
          end
        end
      end

    end
  end
end

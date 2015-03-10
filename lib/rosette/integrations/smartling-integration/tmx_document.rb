# encoding: UTF-8

module Rosette
  module Integrations
    class SmartlingIntegration < Integration

      # To be used when parsing .tmx files using Nokogiri. It turns out to be
      # quite a bit faster to parse this way than parsing the whole document
      # and looking for individual elements with xpath. We do sacrifice a bit
      # of code readability, but the document really isn't that complicated.
      class TmxDocument < Nokogiri::XML::SAX::Document
        attr_reader :locale_code, :proc

        def initialize(locale_code, &block)
          @proc = block
          @locale_code = locale_code
          @capture_key = false
          @capture_prop = false
          @props = {}
        end

        def start_element(name, attrs = [])
          case name
            when 'tu'
              @tuid = get_attr('tuid', attrs)
            when 'prop'
              @prop_type = get_attr('type', attrs)
              @capture_prop = true
            when 'tuv'
              @lang = get_attr('xml:lang', attrs)
            when 'seg'
              @capture_key = (@lang == locale_code)
          end
        end

        def end_element(name)
          case name
            when 'tu'
              if @props['x-segment-id'] == '0'
                meta_key = @props['smartling_string_variant']
                proc.call(meta_key || @tuid, @key)
                @props.clear
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

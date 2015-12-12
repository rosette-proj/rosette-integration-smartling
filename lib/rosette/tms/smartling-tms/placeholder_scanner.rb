# encoding: UTF-8

require 'nokogiri'

module Rosette
  module Tms
    module SmartlingTms

      class PlaceholderScanner
        HTML_TAG_REGEX = /(<\/?\w+\s*(?:\w+\s*=\s*".*?"|'.*?'|[^'">\s]\s*)*>)/
        HTML_ATTRIBUTE_REGEX = /\w+\s*=\s*(".*?"|'.*?'|[^'">\s]\s*)*/
        SMARTLING_PH_REGEX = /(\{ph:\\?\{\d+\\?\}\})/

        attr_reader :regexes, :html_attributes
        alias_method :identify_html_attributes?, :html_attributes

        def initialize(regexes, html_attributes = true)
          @regexes = regexes
          @html_attributes = html_attributes
        end

        def scan(text)
          process_next(text, pipeline, -1)
        end

        protected

        def odd_map(list, pipeline, pipe_idx)
          list.flat_map.with_index do |element, idx|
            if idx % 2 == 1
              if block_given?
                yield element
              else
                element
              end
            else
              process_next(element, pipeline, pipe_idx)
            end
          end
        end

        def process_next(token, pipeline, pipe_idx)
          if pipe = pipeline[pipe_idx + 1]
            send("process_#{pipe}", token, pipeline, pipe_idx + 1)
          else
            []
          end
        end

        def process_html(token, pipeline, pipe_idx)
          odd_map(token.split(HTML_TAG_REGEX), pipeline, pipe_idx) do |tag|
            tag.scan(HTML_ATTRIBUTE_REGEX).flatten.map do |frag|
              strip_quotes(frag)
            end
          end
        end

        def process_regexes(token, pipeline, pipe_idx)
          odd_map(token.split(regex_union), pipeline, pipe_idx)
        end

        def process_smartling_ph(token, pipeline, pipe_idx)
          odd_map(token.split(SMARTLING_PH_REGEX), pipeline, pipe_idx)
        end

        def strip_quotes(text)
          first = text[0]
          last = text[text.size - 1]

          if (first == '"' && last == '"') || (first == "'") && last == "'"
            text[1..-2]
          else
            text
          end
        rescue => e
          text
        end

        def regex_union
          @regex_union ||= Regexp.new("(#{Regexp.union(regexes).source})")
        end

        def pipeline
          @pipeline ||= [].tap do |pl|
            pl << :html if identify_html_attributes?
            pl << :smartling_ph
            pl << :regexes
          end
        end
      end

    end
  end
end

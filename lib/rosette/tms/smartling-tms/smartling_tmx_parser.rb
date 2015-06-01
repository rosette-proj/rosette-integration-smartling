# encoding: UTF-8

require 'tmx-parser'

module Rosette
  module Tms
    module SmartlingTms

      class SmartlingTmxParser
        VARIANT_PROP = 'x-smartling-string-variant'

        class << self
          def load(tmx_contents)
            result = Hash.new { |h, k| h[k] = [] }  # buckets in case of collisions
            TmxParser.load(tmx_contents).each_with_object(result) do |unit, ret|
              variant_prop = unit.properties[VARIANT_PROP]
              meta_key = convert_meta_key(variant_prop.value) if variant_prop
              ret[meta_key] << unit if meta_key
            end
          end

          private

          def convert_meta_key(meta_key)
            meta_key
              .gsub(/:#::?/, '.')          # remove smartling separators
              .gsub(/\A:?[\w\-_]+\./, '')  # remove locale at the front
              .gsub(/\[([\d]+)\]/) do      # replace array elements
                $1.to_i - 1                # subtract 1 because smartling
              end                          # is dumb and starts counting at 1
          end
        end
      end

    end
  end
end

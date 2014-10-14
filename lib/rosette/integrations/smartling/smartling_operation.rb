# encoding: UTF-8

require 'smartling'

module Rosette
  module Integrations
    module Smartling
      class SmartlingOperation

        attr_reader :smartling_api_key, :smartling_project_id, :targeted_locales
        attr_reader :preapprove_translations
        attr_reader :datastore, :repo_name
        attr_accessor :use_sandbox

        alias :preapprove_translations? :preapprove_translations
        alias :use_sandbox? :use_sandbox

        def initialize(api_options = {})
          api_options.keys.each do |key|
            instance_variable_set("@#{key}", api_options[key])
          end
        end

        protected

        def api
          @api ||= begin
            options = {
              apiKey: smartling_api_key,
              projectId: smartling_project_id
            }

            if use_sandbox?
              ::Smartling::File.sandbox(options)
            else
              ::Smartling::File.new(options)
            end
          end
        end

      end
    end
  end
end

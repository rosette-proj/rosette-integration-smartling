# encoding: UTF-8

require 'erb'

class TmxFixture
  class ErbContext
    attr_reader :content, :context

    def initialize(content, context = {})
      @content = content
      @context = context
    end

    def render
      ERB.new(content).result(binding)
    end

    def wrap_placeholders(text)
      text.gsub(/(\{\d+\})/) { "<ph>#{$1}</ph>" }
    end

    def method_missing(method_name, *args, &block)
      if respond_to?(method_name)
        context[method_name]
      else
        raise NoMethodError
      end
    end

    def respond_to?(method_name)
      context.include?(method_name)
    end
  end

  class << self
    def load(name, context = {})
      path = fixture_path_for(name)
      render(path, context)
    end

    protected

    def render(path, context)
      contents = read(path)

      if File.extname(path) == '.erb'
        ErbContext.new(contents, context).render
      else
        contents
      end
    end

    def read(path)
      File.read(path)
    end

    def fixture_path_for(name)
      base = File.join(File.dirname(__FILE__), 'files', name)
      candidates = ["#{base}.tmx", "#{base}.tmx.erb"]
      candidates.find { |file| File.exist?(file) }
    end
  end
end

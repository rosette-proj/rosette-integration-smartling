$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'rosette/integrations/smartling-integration/version'

Gem::Specification.new do |s|
  s.name     = "rosette-integration-smartling"
  s.version  = ::Rosette::Integrations::SMARTLING_INTEGRATION_VERSION
  s.authors  = ["Cameron Dutro"]
  s.email    = ["camertron@gmail.com"]
  s.homepage = "http://github.com/camertron"

  s.description = s.summary = "Smartling support for the Rosette internationalization platform."

  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true

  s.add_dependency 'nokogiri', '1.6.0'

  s.require_path = 'lib'
  s.files = Dir["{lib,spec}/**/*", "Gemfile", "History.txt", "README.md", "Rakefile", "rosette-integration-smartling.gemspec"]
end

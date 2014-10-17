# encoding: UTF-8

require 'pry-nav'

require 'rspec'
require 'jbundler'
require 'tmp-repo'
require 'rosette/core'
require 'rosette/integrations/smartling'
require 'rosette/serializers/json-serializer'
require 'rosette/data_stores/in_memory_data_store'

RSpec.configure do |config|
  # rspec config
end

class NilLogger
  def info(msg); end
  def warn(msg); end
  def error(msg); end
end

Rosette.logger = NilLogger.new

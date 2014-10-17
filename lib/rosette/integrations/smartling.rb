# encoding: UTF-8

require 'smartling'
require 'rosette/integrations/smartling/errors'

module Rosette
  module Integrations
    module Smartling

      autoload :SmartlingApi,       'rosette/integrations/smartling/smartling_api'
      autoload :SmartlingPusher,    'rosette/integrations/smartling/smartling_puller'
      autoload :SmartlingPuller,    'rosette/integrations/smartling/smartling_pusher'
      autoload :SmartlingCompleter, 'rosette/integrations/smartling/smartling_completer'

      autoload :SmartlingFile,      'rosette/integrations/smartling/smartling_file'
      autoload :SmartlingFileList,  'rosette/integrations/smartling/smartling_file_list'

    end
  end
end

# encoding: UTF-8

require 'smartling'

module Rosette
  module Integrations
    module Smartling

      autoload :SmartlingOperation, 'rosette/integrations/smartling/smartling_operation'
      autoload :SmartlingPusher, 'rosette/integrations/smartling/smartling_puller'
      autoload :SmartlingPuller, 'rosette/integrations/smartling/smartling_pusher'
      autoload :SmartlingCompleter, 'rosette/integrations/smartling/smartling_completer'

      autoload :SmartlingFile, 'rosette/integrations/smartling/smartling_file'
      autoload :SmartlingFileList, 'rosette/integrations/smartling/smartling_file_list'

    end
  end
end

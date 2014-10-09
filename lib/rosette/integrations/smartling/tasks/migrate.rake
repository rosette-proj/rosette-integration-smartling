# encoding: UTF-8

require 'rosette/integrations/smartling/tasks/schema_manager'

namespace :rosette do
  namespace :smartling do

    task :setup do
      SchemaManager.setup
    end

    task :migrate do
      SchemaManager.migrate
    end

    task :rollback do
      SchemaManager.rollback
    end

  end
end

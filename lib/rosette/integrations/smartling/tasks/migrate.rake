# encoding: UTF-8

require 'rosette/integrations/smartling/tasks/schema_manager'

namespace :rosette do
  namespace :smartling do

    task :setup do
      Rosette::Integrations::Smartling::SchemaManager.setup
    end

    task :migrate do
      Rosette::Integrations::Smartling::SchemaManager.migrate
    end

    task :rollback do
      Rosette::Integrations::Smartling::SchemaManager.rollback
    end

  end
end

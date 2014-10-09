# encoding: UTF-8

$:.unshift File.join(File.dirname(__FILE__), 'lib')

require 'rubygems' unless ENV['NO_RUBYGEMS']

require 'bundler'
require 'rspec/core/rake_task'
require 'rubygems/package_task'

require 'rosette/integrations/smartling'
require 'rosette/integrations/smartling/tasks/schema_manager'

Bundler::GemHelper.install_tasks

task :default => :spec

desc 'Run specs'
RSpec::Core::RakeTask.new do |t|
  t.pattern = './spec/**/*_spec.rb'
end

namespace :db do
  ActiveRecord::Base.establish_connection(
    YAML.load_file(
      File.expand_path('spec/database.yml', File.dirname(__FILE__))
    )
  )

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

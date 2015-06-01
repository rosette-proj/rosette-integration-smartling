# encoding: UTF-8

require 'pry-nav'

require 'rspec'
require 'jbundler'
require 'tmp-repo'
require 'rosette/core'
require 'rosette/tms/smartling-tms'
require 'rosette/data_stores/in_memory_data_store'
require 'rosette/test-helpers'
require 'spec/fixtures/tmx/tmx_fixture'
require 'tmx-parser'

RSpec.configure do |config|
  # build all fixtures before tests run
  Rosette::TestHelpers::Fixtures.build_all

  def load_repo_fixture(*args)
    Rosette::TestHelpers::Fixtures.load_repo_fixture(*args) do |config, repo_config|
      repo_config.add_extractor('test/test') do |ext|
        ext.set_conditions do |conditions|
          conditions.match_file_extension('.txt')
        end
      end

      yield config, repo_config if block_given?
    end
  end

  config.after(:each) do
    Rosette::TestHelpers::Fixtures.cleanup
    Rosette::DataStores::InMemoryDataStore.all_entries.clear
  end

  def create_file_uri(repo_name, author, commit_id)
    "#{repo_name}/#{author}/#{commit_id}.yml"
  end

  def create_tmp_file_uri(repo_name, commit_id)
    "#{repo_name}/#{commit_id}.yml"
  end

  def fake_hex_string(length = 10)
    (('a'..'z').to_a + ('0'..'9').to_a).sample(length).join
  end

  def fake_string(length = 10)
    ('a'..'z').to_a.sample(length).join
  end

  def create_file_entry(options = {})
    {
      'fileUri' => options['fileUri'] || create_file_uri(
        options.fetch('repo_name', fake_string),
        options.fetch('author', "#{fake_string} #{fake_string}"),
        options.fetch('commit_id', fake_hex_string(38))
      ),
      'stringCount' => options.fetch('stringCount', 1),
      'wordCount' => options.fetch('wordCount', 2),
      'approvedStringCount' => options.fetch('approvedStringCount', 0),
      'completedStringCount' => options.fetch('completedStringCount', 0),
      'lastUploaded' => options.fetch('lastUploaded', Time.now.strftime('%Y-%m-%dT%H:%M:%S')),
      'fileType' => options.fetch('fileType', 'yaml')
    }
  end

  def create_tmp_file_entry(options = {})
    create_file_entry(options).merge(
      'fileUri' => create_tmp_file_uri(
        options.fetch('repo_name', fake_string),
        options.fetch('commit_id', fake_hex_string(38))
      )
    )
  end

  def create_file_list(files)
    case files
      when Array
        { 'fileCount' => files.size, 'fileList' => files }
      when Fixnum
        {
          'fileCount' => files,
          'fileList' => files.times.map { create_file_entry }
        }
    end
  end

  def create_tmp_file_list(files)
    case files
      when Array
        { 'fileCount' => files.size, 'fileList' => files }
      when Fixnum
        {
          'fileCount' => files,
          'fileList' => files.times.map { create_tmp_file_entry }
        }
    end
  end
end

Rosette.logger = NullLogger.new

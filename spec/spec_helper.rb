# encoding: UTF-8

require 'pry-nav'

require 'rspec'
require 'jbundler'
require 'tmp-repo'
require 'rosette/core'
require 'rosette/integrations/smartling-integration'
require 'rosette/serializers/yaml-serializer'
require 'rosette/extractors/yaml-extractor'
require 'rosette/data_stores/in_memory_data_store'

RSpec.configure do |config|
  def create_file_uri(repo_name, author, commit_id)
    "#{repo_name}/#{author}/#{commit_id}.yml"
  end

  def fake_hex_string(length = 10)
    (('a'..'z').to_a + ('0'..'9').to_a).sample(length).join
  end

  def fake_string(length = 10)
    ('a'..'z').to_a.sample(length).join
  end

  def create_file_entry(options = {})
    {
      'fileUri' => create_file_uri(
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
end

class NilLogger
  def info(msg); end
  def warn(msg); end
  def error(msg); end
end

Rosette.logger = NilLogger.new

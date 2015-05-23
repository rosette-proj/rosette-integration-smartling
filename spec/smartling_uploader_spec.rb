# encoding: UTF-8

require 'spec_helper'

include Rosette::Tms::SmartlingTms
include Rosette::DataStores

module Rosette
  module Serializers
    class XmlSerializer < Serializer
      class AndroidSerializer < XmlSerializer
        def write_key_value(key, val); end
        def write_raw(str); end
        def self.default_extension
          '.xml'
        end
      end
    end
  end
end

describe SmartlingUploader do
  let(:repo_name) { 'test_repo' }

  let(:rosette_config) do
    Rosette.build_config do |config|
      config.add_repo(repo_name) do |repo_config|
        repo_config.add_serializer('rails', format: 'yaml/rails')
        repo_config.use_tms('smartling') do |smartling_config|
          smartling_config.set_serializer(serializer_id)
          smartling_config.smartling_api.instance_variable_set(
            :'@api', smartling_api_base
          )
        end
      end
    end
  end

  let(:repo_config) { rosette_config.get_repo(repo_name) }
  let(:configurator) { repo_config.tms.configurator }
  let(:serializer_id) { 'yaml/rails' }
  let(:file_name) { 'my_file_name' }
  let(:smartling_api_base) { double(:smartling_api) }
  let(:integration_config) { repo_config.get_integration('smartling') }

  let(:phrases) do
    [InMemoryDataStore::Phrase.create(
      repo_name: repo_name,
      key: 'foobar_key',
      meta_key: 'foobar_metakey',
      commit_id: '123abc',
      file: 'foo.txt'
    )]
  end

  let(:uploader) do
    SmartlingUploader.new(configurator)
      .set_file_uri(file_name)
      .set_phrases(phrases)
  end

  describe '#upload' do
    it 'uploads the phrases' do
      expect(smartling_api_base).to(
        receive(:upload).with(
          anything, file_name, 'yaml', anything
        )
      )

      uploader.upload
    end

    context 'with an xml/android serializer' do
      before(:each) do
        repo_config.add_serializer('android', format: 'xml/android')
      end

      let(:serializer_id) { 'xml/android' }

      it 'correctly detects the smartling file type to use' do
        expect(smartling_api_base).to(
          receive(:upload).with(
            anything, file_name, 'android', anything
          )
        )

        uploader.upload
      end
    end
  end
end

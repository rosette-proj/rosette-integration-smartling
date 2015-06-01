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
  let(:repo_name) { 'single_commit' }
  let(:rosette_config) { fixture.config }
  let(:serializer_id) { 'test/test' }

  let(:fixture) do
    load_repo_fixture(repo_name) do |config, repo_config|
      repo_config.use_tms('smartling') do |smartling_config|
        smartling_config.set_serializer(serializer_id)
      end
    end
  end

  let(:repo_config) { rosette_config.get_repo(repo_name) }
  let(:configurator) { repo_config.tms.configurator }
  let(:file_name) { 'my_file_name' }

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
      expect(configurator.smartling_api).to(
        receive(:upload).with(
          anything, file_name, nil, anything
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
        expect(configurator.smartling_api).to(
          receive(:upload).with(
            anything, file_name, 'android', anything
          )
        )

        uploader.upload
      end
    end
  end
end

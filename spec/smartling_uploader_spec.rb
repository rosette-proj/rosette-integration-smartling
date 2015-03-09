# encoding: UTF-8

require 'spec_helper'

include Rosette::Integrations
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

describe SmartlingIntegration::SmartlingUploader do
  let(:repo_name) { 'test_repo' }

  let(:rosette_config) do
    Rosette.build_config do |config|
      config.add_repo(repo_name) do |repo_config|
        repo_config.add_serializer('rails', format: 'yaml/rails')
        repo_config.add_integration('smartling')
      end
    end
  end

  let(:repo_config) { rosette_config.get_repo(repo_name) }
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
    SmartlingIntegration::SmartlingUploader.new(rosette_config)
      .set_repo_config(repo_config)
      .set_phrases(phrases)
      .set_file_name(file_name)
      .set_serializer_id(serializer_id)
  end

  before(:each) do
    integration_config.smartling_api.instance_variable_set(
      :'@api', smartling_api_base
    )
  end

  describe '#upload' do
    it 'uploads the phrases' do
      expect(smartling_api_base).to(
        receive(:upload).with(
          anything, "#{repo_name}/#{file_name}.yml", 'yaml', anything
        )
      )

      uploader.upload
    end

    it 'uses the given smartling api instead of the one in the integration config' do
      other_api_base = double(:other_api)
      other_api = SmartlingIntegration::SmartlingApi.new
      other_api.instance_variable_set(:'@api', other_api_base)
      uploader.set_smartling_api(other_api)

      expect(other_api).to receive(:upload)
      expect(smartling_api_base).to_not receive(:upload)
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
            anything, "#{repo_name}/#{file_name}.xml", 'android', anything
          )
        )

        uploader.upload
      end
    end
  end

  describe '#destination_file_uri' do
    it 'prepends the name of the repo' do
      expect(uploader.destination_file_uri).to(
        eq("#{repo_name}/#{file_name}.yml")
      )
    end

    context 'with an xml/android serializer' do
      let(:serializer_id) { 'xml/android' }

      it "appends the serializer's default extension" do
        expect(uploader.destination_file_uri).to(
          eq("#{repo_name}/#{file_name}.xml")
        )
      end
    end
  end
end

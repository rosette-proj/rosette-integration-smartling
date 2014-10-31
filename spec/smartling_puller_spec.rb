# encoding: UTF-8

require 'spec_helper'

include Rosette::Integrations
include Rosette::DataStores

describe SmartlingIntegration::SmartlingPuller do
  let(:repo_name) { 'test_repo' }
  let(:author) { 'KathrynJaneway' }
  let(:locale) { 'ko-KR' }
  let(:repo) { TmpRepo.new }

  let(:configuration) do
    Rosette.build_config do |config|
      config.use_datastore('in-memory')
      config.add_repo(repo_name) do |repo_config|
        repo_config.set_path(File.join(repo.working_dir, '/.git'))
      end
    end
  end

  let(:puller) { SmartlingIntegration::SmartlingPuller.new(configuration, smartling_api) }
  let(:smartling_api_base) { double(:smartling_api) }
  let(:smartling_api) { SmartlingIntegration::SmartlingApi.new }
  let(:rosette_api) { double(:rosette_api) }
  let(:extractor_id) { 'yaml/rails' }
  let(:commit_id) { repo.git('rev-parse HEAD').strip }
  let(:file_uri_params) { { 'repo_name' => repo_name, 'author' => author, 'commit_id' => commit_id }}

  before(:each) do
    repo.create_file('foo.txt') do |f|
      f.write('I just need a commit')
    end

    repo.add_all
    repo.commit('First commit')

    InMemoryDataStore::CommitLogLocale.create(
      commit_id: commit_id,
      locale: locale,
      translated_count: 1
    )

    allow(smartling_api_base).to receive(:download).and_return(
      YAML.dump(locale => { 'foo' => { 'bar' => 'baz' } })
    )

    smartling_api.instance_variable_set(:'@api', smartling_api_base)
  end

  context 'with a single configured extractor' do
    before(:each) do
      configuration.get_repo(repo_name).add_extractor(extractor_id)

      expect(rosette_api).to receive(:add_or_update_translation).with({
        meta_key: 'foo.bar', ref: commit_id,
        translation: 'baz', locale: locale,
        repo_name: repo_name
      })
    end

    it 'updates the commit log and calls the api to add/update translations' do
      expect(smartling_api_base).to receive(:list).and_return(
        create_file_list([create_file_entry(file_uri_params.merge('completedStringCount' => 2))])
      )

      puller.pull(locale, extractor_id, rosette_api)

      commit_log_locale = InMemoryDataStore::CommitLogLocale.find do |entry|
        entry.commit_id == commit_id && entry.locale == locale
      end

      expect(commit_log_locale.translated_count).to eq(2)
    end

    it 'encodes data correctly before handing it to the extractor' do
      expect(smartling_api_base).to receive(:list).and_return(
        create_file_list([create_file_entry(file_uri_params.merge('completedStringCount' => 2))])
      )

      allow(smartling_api_base).to receive(:download).and_return(
        YAML.dump(locale => { 'foo' => { 'bar' => 'baz' } }).encode(Encoding::UTF_16BE)
      )

      puller.pull(locale, extractor_id, rosette_api, Encoding::UTF_16BE)

      commit_log_locale = InMemoryDataStore::CommitLogLocale.find do |entry|
        entry.commit_id == commit_id && entry.locale == locale
      end

      expect(commit_log_locale.translated_count).to eq(2)
    end
  end

  context 'with multiple configured extractors with different encodings' do
    before(:each) do
      repo_config = configuration.get_repo(repo_name)

      repo_config.add_extractor(extractor_id) do |ext|
        ext.set_encoding(Encoding::UTF_8)
      end

      repo_config.add_extractor(extractor_id) do |ext|
        ext.set_encoding(Encoding::UTF_16BE)
      end
    end

    it 'raises an exception because of encoding ambiguity' do
      expect(smartling_api_base).to receive(:list).and_return(
        create_file_list([create_file_entry(file_uri_params.merge('completedStringCount' => 2))])
      )

      expect { puller.pull(locale, extractor_id, rosette_api) }.to(
        raise_error(SmartlingIntegration::Errors::AmbiguousEncodingError)
      )
    end

    it 'does not throw an error if an explicit encoding is passed' do
      expect(rosette_api).to receive(:add_or_update_translation).with({
        meta_key: 'foo.bar', ref: commit_id,
        translation: 'baz', locale: locale,
        repo_name: repo_name
      })

      expect(smartling_api_base).to receive(:list).and_return(
        create_file_list([create_file_entry(file_uri_params.merge('completedStringCount' => 2))])
      )

      expect { puller.pull(locale, extractor_id, rosette_api, Encoding::UTF_8) }.to_not raise_error
    end
  end
end

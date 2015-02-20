# encoding: UTF-8

require 'spec_helper'

include Rosette::Integrations
include Rosette::DataStores

describe SmartlingIntegration::SmartlingPuller do
  let(:repo_name) { 'test_repo' }
  let(:locales) { ['es-ES', 'pt-BR'] }
  let(:repo) { TmpRepo.new }

  let(:rosette_config) do
    Rosette.build_config do |config|
      config.use_datastore('in-memory')
      config.use_error_reporter(Rosette::Core::RaisingErrorReporter.new)
      config.add_repo(repo_name) do |repo_config|
        repo_config.set_path(File.join(repo.working_dir, '/.git'))
        repo_config.add_locales(locales)
        repo_config.add_integration('smartling')
        repo_config.add_extractor('yaml/rails')
      end
    end
  end

  let(:serializer_id) { 'yaml/rails' }
  let(:extractor_id) { 'yaml/rails' }
  let(:repo_config) { rosette_config.get_repo(repo_name) }
  let(:smartling_api_base) { double(:smartling_api) }
  let(:commit_id) { repo.git('rev-parse HEAD').strip }
  let(:integration_config) { repo_config.get_integration('smartling') }
  let(:file_uri) { "#{repo_name}/#{commit_id}.yml" }

  let(:puller) do
    SmartlingIntegration::SmartlingPuller.new(rosette_config)
      .set_repo_config(repo_config)
      .set_serializer_id(serializer_id)
      .set_extractor_id(extractor_id)
      .set_thread_pool_size(0)
  end

  let(:phrase) do
    InMemoryDataStore::Phrase.create(
      repo_name: repo_name,
      commit_id: commit_id,
      meta_key: 'phrase',
      key: "I'm a little teapot",
      file: 'foo.txt'
    )
  end

  let(:translation_memory_hash) do
    locales.each_with_object({}) do |locale, ret|
      ret[locale] ||= {}
      ret[locale][phrase.meta_key] = phrase
    end
  end

  let(:translation_memory) do
    SmartlingIntegration::TranslationMemory.new(
      translation_memory_hash
    )
  end

  before(:each) do
    repo.create_file('foo.txt') do |f|
      f.write("en:\n  phrase: I'm a little teapot\n")
    end

    repo.add_all
    repo.commit('First commit')

    locales.each do |locale|
      InMemoryDataStore::CommitLogLocale.create(
        commit_id: commit_id,
        locale: locale,
        translated_count: 1
      )
    end

    InMemoryDataStore::CommitLog.create(
      repo_name: repo_name,
      commit_id: commit_id,
      status: 'PENDING',
      phrase_count: 1
    )

    integration_config.smartling_api.instance_variable_set(
      :'@api', smartling_api_base
    )

    allow(puller).to(
      receive(:build_translation_memory).and_return(translation_memory)
    )
  end

  after(:each) do
    repo.unlink
  end

  it 'pulls strings for each pending commit' do
    puller.pull

    locales.each do |locale|
      trans = InMemoryDataStore::Translation.find { |trans| trans.locale == locale }
      expect(trans.phrase.key).to eq("I'm a little teapot")
      expect(trans.phrase.meta_key).to eq('phrase')
      expect(trans.translation).to eq("I'm a little teapot")
      expect(trans.locale).to eq(locale)

      locale_entry = InMemoryDataStore::CommitLogLocale.find do |entry|
        entry.commit_id == commit_id && locale == locale
      end

      expect(locale_entry).to_not be_nil
    end

    commit_log_entry = InMemoryDataStore::CommitLog.find do |entry|
      entry.commit_id == commit_id && entry.repo_name == repo_name
    end
  end

  context 'with an empty translation memory' do
    let(:translation_memory_hash) { {} }

    it 'marks the commit as translated' do
      commit_log_entry = InMemoryDataStore::CommitLog.find do |entry|
        entry.commit_id == commit_id && entry.repo_name == repo_name
      end

      commit_log_entry.attributes[:phrase_count] = 0
      puller.pull

      expect(commit_log_entry.status).to eq(
        Rosette::DataStores::PhraseStatus::TRANSLATED
      )
    end
  end
end

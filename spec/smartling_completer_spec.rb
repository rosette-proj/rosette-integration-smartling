# encoding: UTF-8

require 'spec_helper'

include Rosette::Integrations
include Rosette::DataStores

describe SmartlingIntegration::SmartlingCompleter do
  let(:repo_name) { 'test_repo' }
  let(:locales) { ['ko-KR', 'ja-JP'] }
  let(:repo) { TmpRepo.new }

  let(:rosette_config) do
    Rosette.build_config do |config|
      config.use_datastore('in-memory')
      config.use_error_reporter(Rosette::Core::RaisingErrorReporter.new)
      config.add_repo(repo_name) do |repo_config|
        repo_config.add_locales(locales)
        repo_config.set_path(File.join(repo.working_dir, '/.git'))
        repo_config.add_integration('smartling')
      end
    end
  end

  let(:completer) do
    SmartlingIntegration::SmartlingCompleter.new(rosette_config)
      .set_repo_config(repo_config)
      .set_thread_pool_size(0)
  end

  let(:repo_config) { rosette_config.get_repo(repo_name) }
  let(:integration_config) { repo_config.get_integration('smartling') }
  let(:smartling_api_base) { double(:smartling_api) }
  let(:incomplete_files) { [create_file_entry] }
  let(:complete_files) do
    3.times.map do
      create_file_entry(
        'repo_name' => repo_name,
        'stringCount' => 1,
        'completedStringCount' => 1
      )
    end
  end

  let(:commit_id) do
    SmartlingIntegration::SmartlingFile
      .list_from_api_response(complete_file_list)
      .first
      .commit_id
  end

  let(:complete_file_list) do
    create_file_list(complete_files)
  end

  before(:each) do
    integration_config.smartling_api.instance_variable_set(
      :'@api', smartling_api_base
    )

    InMemoryDataStore::CommitLog.create(
      repo_name: repo_name,
      commit_id: commit_id,
      status: Rosette::DataStores::PhraseStatus::PULLING
    )
  end

  after(:each) do
    repo.unlink
  end

  describe '#complete' do
    before(:each) do
      expect(smartling_api_base).to(
        receive(:list)
          .with(locale: 'ko-KR', offset: 0, limit: 100)
          .and_return(
            create_file_list(complete_files + incomplete_files)
          )
      )

      expect(smartling_api_base).to(
        receive(:list)
          .with(locale: 'ko-KR', offset: 1, limit: 100)
          .and_return(create_file_list(0))
      )

      expect(smartling_api_base).to(
        receive(:list)
          .with(locale: 'ja-JP', offset: 0, limit: 100)
          .and_return(complete_file_list)
      )

      expect(smartling_api_base).to(
        receive(:list)
          .with(locale: 'ja-JP', offset: 1, limit: 100)
          .and_return(create_file_list(0))
      )
    end

    it 'deletes files that are complete in every locale' do
      # should delete files that are complete in all locales
      complete_files.each do |file|
        expect(smartling_api_base).to receive(:delete).with(file['fileUri'])
      end

      completer.complete

      commit_log_entry = InMemoryDataStore::CommitLog.find do |entry|
        entry.commit_id == commit_id && entry.repo_name == repo_name
      end

      expect(commit_log_entry.status).to eq(
        Rosette::DataStores::PhraseStatus::PULLED
      )
    end

    it 'transitions commit logs from PULLED to TRANSLATED' do
      # should delete files that are complete in all locales
      complete_files.each do |file|
        expect(smartling_api_base).to receive(:delete).with(file['fileUri'])
      end

      commit_log_entry = InMemoryDataStore::CommitLog.find do |entry|
        entry.commit_id == commit_id && entry.repo_name == repo_name
      end

      commit_log_entry.status = Rosette::DataStores::PhraseStatus::PULLED
      completer.complete

      expect(commit_log_entry.status).to eq(
        Rosette::DataStores::PhraseStatus::TRANSLATED
      )
    end
  end
end

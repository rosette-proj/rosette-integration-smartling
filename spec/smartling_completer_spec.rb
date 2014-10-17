# encoding: UTF-8

require 'spec_helper'

include Rosette::Integrations::Smartling
include Rosette::DataStores

describe SmartlingCompleter do
  let(:repo_name) { 'test_repo' }
  let(:repo) { TmpRepo.new }

  let(:configuration) do
    Rosette.build_config do |config|
      config.use_datastore('in-memory')
      config.add_repo(repo_name) do |repo_config|
        repo_config.set_path(File.join(repo.working_dir, '/.git'))
      end
    end
  end

  let(:completer) { SmartlingCompleter.new(configuration, smartling_api) }
  let(:locales) { ['ko-KR', 'ja-JP'] }
  let(:smartling_api_base) { double(:smartling_api) }
  let(:smartling_api) { SmartlingApi.new(smartling_api_base) }
  let(:incomplete_files) { [create_file_entry] }
  let(:complete_files) do
    3.times.map do
      create_file_entry('stringCount' => 1, 'completedStringCount' => 1)
    end
  end

  describe '#complete' do
    it 'deletes files that are complete in every locale, updates commit log' do
      expect(smartling_api_base).to receive(:list).with(locale: 'ko-KR').and_return(
        create_file_list(complete_files + incomplete_files)
      )

      expect(smartling_api_base).to receive(:list).with(locale: 'ja-JP').and_return(
        create_file_list(complete_files)
      )

      # should delete files that are complete in all locales
      complete_files.each do |file|
        expect(smartling_api_base).to receive(:delete).with(file['fileUri'])
      end

      completer.complete(locales)

      SmartlingFileList.from_api_response(create_file_list(complete_files)).each do |file|
        commit_log_entry = InMemoryDataStore::CommitLog.find do |entry|
          file.commit_id == entry.commit_id && entry.repo_name
        end

        expect(commit_log_entry.status).to eq('TRANSLATED')
      end

      SmartlingFileList.from_api_response(create_file_list(incomplete_files)).each do |file|
        commit_log_entry = InMemoryDataStore::CommitLog.find do |entry|
          file.commit_id == entry.commit_id && entry.repo_name
        end

        expect(commit_log_entry).to be_nil
      end
    end
  end
end

# encoding: UTF-8

require 'spec_helper'

include Rosette::Integrations
include Rosette::DataStores

describe SmartlingIntegration::SmartlingPusher do
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

  let(:pusher) { SmartlingIntegration::SmartlingPusher.new(configuration, repo_name, smartling_api) }
  let(:commit_id) { repo.git('rev-parse HEAD').strip }
  let(:smartling_api_base) { double(:smartling_api) }
  let(:smartling_api) { SmartlingIntegration::SmartlingApi.new }
  let(:serializer) { 'yaml/rails' }

  before(:each) do
    smartling_api.instance_variable_set(:'@api', smartling_api_base)
  end

  def add_file_to_repo
    repo.create_file('foo.txt') do |f|
      f.write("foobar_key")
    end

    repo.add_all
    repo.commit('First commit')

    InMemoryDataStore::Phrase.create(
      repo_name: repo_name,
      key: 'foobar_key',
      meta_key: nil,
      commit_id: commit_id
    )
  end

  context 'with a committed file' do
    before(:each) do
      add_file_to_repo
    end

    describe '#push' do
      it 'uploads strings to smartling and updates the commit log' do
        expect(smartling_api_base).to receive(:upload).and_return({ 'stringCount' => 1 })
        pusher.push(commit_id, serializer)

        log_entry = InMemoryDataStore::CommitLog.find do |entry|
          entry.repo_name == repo_name &&
            entry.commit_id == commit_id
        end

        expect(log_entry.status).to eq('PENDING')
        expect(log_entry.phrase_count).to eq(1)
      end

      it '(re)raises errors on smartling api error' do
        expect(smartling_api_base).to receive(:upload).and_raise('Jelly beans')
        expect { pusher.push(commit_id, serializer) }.to raise_error('Jelly beans')
      end
    end
  end

  describe '#push' do
    it "uses the git author's name in the smartling file uri" do
      repo.git("config user.name 'Kathryn Janeway'")
      add_file_to_repo

      expect(smartling_api_base).to receive(:upload)
        .with(anything, "#{repo_name}/KathrynJaneway/#{commit_id}.yml", anything, anything)
        .and_return({ 'stringCount' => 1 })

      pusher.push(commit_id, serializer)
    end

    it "falls back to the first half of the git author's email if name is not set" do
      repo.git("config user.email kjaneway@starfleet.org")
      add_file_to_repo

      allow(pusher).to receive(:get_identity_string_from_name).and_return(nil)

      expect(smartling_api_base).to receive(:upload)
        .with(anything, "#{repo_name}/kjaneway/#{commit_id}.yml", anything, anything)
        .and_return({ 'stringCount' => 1 })

      pusher.push(commit_id, serializer)
    end

    it 'falls back to "unknown" if both the author name and email are unset' do
      add_file_to_repo

      allow(pusher).to receive(:get_identity_string_from_name).and_return(nil)
      allow(pusher).to receive(:get_identity_string_from_email).and_return(nil)

      expect(smartling_api_base).to receive(:upload)
        .with(anything, "#{repo_name}/unknown/#{commit_id}.yml", anything, anything)
        .and_return({ 'stringCount' => 1 })

      pusher.push(commit_id, serializer)
    end
  end
end

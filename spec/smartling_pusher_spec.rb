# encoding: UTF-8

require 'spec_helper'

include Rosette::Integrations
include Rosette::DataStores

describe SmartlingIntegration::SmartlingPusher do
  let(:repo_name) { 'test_repo' }
  let(:repo) { TmpRepo.new }

  let(:rosette_config) do
    Rosette.build_config do |config|
      config.use_datastore('in-memory')
      config.use_error_reporter(Rosette::Core::RaisingErrorReporter.new)
      config.add_repo(repo_name) do |repo_config|
        repo_config.set_path(File.join(repo.working_dir, '/.git'))
        repo_config.add_integration('smartling') do |integration_config|
          integration_config.set_directives(directives)
        end
      end
    end
  end

  let(:directives) { '# bogus directives' }
  let(:repo_config) { rosette_config.get_repo(repo_name) }
  let(:integration_config) { repo_config.get_integration('smartling') }

  let(:pusher) do
    SmartlingIntegration::SmartlingPusher.new(rosette_config)
      .set_repo_config(repo_config)
  end

  let(:commit_id) { repo.git('rev-parse HEAD').strip }
  let(:smartling_api_base) { double(:smartling_api) }
  let(:serializer_id) { 'yaml/rails' }

  before(:each) do
    integration_config.smartling_api.instance_variable_set(
      :'@api', smartling_api_base
    )
  end

  def add_file_to_repo
    repo.create_file('foo.txt') do |f|
      f.write("foobar_metakey: foobar_key\n")
    end

    repo.add_all
    repo.commit('First commit')

    InMemoryDataStore::Phrase.create(
      repo_name: repo_name,
      key: 'foobar_key',
      meta_key: 'foobar_metakey',
      commit_id: commit_id,
      file: 'foo.txt'
    )
  end

  describe '#push' do
    it 'uploads strings to smartling and updates the commit log' do
      add_file_to_repo

      expect(smartling_api_base).to receive(:upload).and_return({ 'stringCount' => 1 })
      pusher.push(commit_id, serializer_id)

      log_entry = InMemoryDataStore::CommitLog.find do |entry|
        entry.repo_name == repo_name &&
          entry.commit_id == commit_id
      end

      expect(log_entry.status).to eq('PENDING')
      expect(log_entry.phrase_count).to eq(1)
    end

    it '(re)raises errors on smartling api error' do
      add_file_to_repo

      allow(smartling_api_base).to receive(:upload).and_raise('Jelly beans')
      expect { pusher.push(commit_id, serializer_id) }.to raise_error('Jelly beans')
    end

    it "uses the git author's name in the smartling file uri" do
      repo.git("config user.name 'Kathryn Janeway'")
      add_file_to_repo

      expect(smartling_api_base).to receive(:upload)
        .with(anything, "#{repo_name}/KathrynJaneway/#{commit_id}.yml", anything, anything)
        .and_return({ 'stringCount' => 1 })

      pusher.push(commit_id, serializer_id)
    end

    it "falls back to the first half of the git author's email if name is not set" do
      repo.git("config user.email kjaneway@starfleet.org")
      add_file_to_repo

      allow(pusher).to receive(:get_identity_string_from_name).and_return(nil)

      expect(smartling_api_base).to receive(:upload)
        .with(anything, "#{repo_name}/kjaneway/#{commit_id}.yml", anything, anything)
        .and_return({ 'stringCount' => 1 })

      pusher.push(commit_id, serializer_id)
    end

    it 'falls back to "unknown" if both the author name and email are unset' do
      add_file_to_repo

      allow(pusher).to receive(:get_identity_string_from_name).and_return(nil)
      allow(pusher).to receive(:get_identity_string_from_email).and_return(nil)

      expect(smartling_api_base).to receive(:upload)
        .with(anything, "#{repo_name}/unknown/#{commit_id}.yml", anything, anything)
        .and_return({ 'stringCount' => 1 })

      pusher.push(commit_id, serializer_id)
    end
  end
end

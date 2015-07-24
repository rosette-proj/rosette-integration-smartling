# encoding: UTF-8

require 'spec_helper'

include Rosette::Tms
include Rosette::Tms::SmartlingTms
include Rosette::Core
include Rosette::DataStores
include Rosette::Queuing

describe SmartlingFile do
  class Probe
    attr_reader :counter

    def initialize(error_klass, message)
      @error_klass = error_klass
      @message = message
      @counter = 0
    end

    def delete(*args)
      if counter == 0
        raise @error_klass, @message
      end
    ensure
      @counter += 1
    end
  end

  let(:repo_name) { 'single_commit' }
  let(:locale_code) { 'de-DE' }
  let(:locale) { repo_config.locales.first }
  let(:commit_id) { fixture.repo.git('rev-parse HEAD').strip }
  let(:git_user) { fixture.repo.git('config user.name').gsub(/[^\w]/, '') }
  let(:not_found_error_message) do
    "VALIDATION_ERROR The file #{file.file_uri} could not be found"
  end

  let(:fixture) do
    load_repo_fixture(repo_name) do |config, repo_config|
      config.use_datastore('in-memory')
      repo_config.add_locale(locale_code)
      repo_config.use_tms('smartling') do |tms_config|
        tms_config.set_serializer('test/test')
      end
    end
  end

  let(:rosette_config) { fixture.config }
  let(:repo_config) { rosette_config.get_repo(repo_name) }

  let(:configurator) do
    repo_config.tms.configurator
  end

  let!(:commit_log) do
    InMemoryDataStore::CommitLog.create(
      status: PhraseStatus::FETCHED,
      repo_name: repo_name,
      commit_id: commit_id,
      phrase_count: 0,
      commit_datetime: nil,
      branch_name: 'refs/heads/origin/my_branch'
    )
  end

  let(:phrase) { InMemoryDataStore::Phrase.create(key: 'foobar', meta_key: 'foo.bar') }
  let(:granularity) { Commits::PhraseStorageGranularity::COMMIT }
  let(:file) { SmartlingFile.new(configurator, commit_id) }

  before(:each) do
    configurator.set_phrase_storage_granularity(granularity)
  end

  context 'with a canned status from the smartling api' do
    before(:each) do
      allow(file).to receive(:fetch_status).and_return(
        'fileUri' => 'foo/bar/baz.txt',
        'stringCount' => 10,
        'completedStringCount' => 5
      )
    end

    describe '#phrase_count' do
      it 'returns the correct value from the api response' do
        expect(file.phrase_count).to eq(10)
      end
    end

    describe '#file_uri' do
      it 'adds the git user, repo name, and commit id to the filename' do
        expect(file.file_uri).to eq("#{repo_name}/#{git_user}/#{commit_id}.txt")
      end
    end

    describe '#upload' do
      it 'uploads the phrases via the smartling api' do
        expect(configurator.smartling_api).to(
          receive(:upload).with(anything, file.file_uri, anything, anything)
        )

        file.upload([phrase])
      end
    end

    describe '#download' do
      it 'downloads translations via the smartling api' do
        expect(configurator.smartling_api).to(
          receive(:download).with(file.file_uri, locale: locale.code)
        )

        file.download(locale)
      end
    end

    describe '#delete' do
      it 'deletes the file from smartling via the api' do
        expect(configurator.smartling_api).to(
          receive(:delete).with(file.file_uri)
        )

        file.delete
      end

      it 'retries on error' do
        probe = Probe.new(StandardError, 'test test test')
        allow(configurator).to receive(:smartling_api).and_return(probe)
        file.delete
        expect(probe.counter).to eq(2)
      end

      it "does not retry or raise an error if the file doesn't exist" do
        probe = Probe.new(RuntimeError, not_found_error_message)
        allow(configurator).to receive(:smartling_api).and_return(probe)
        expect { file.delete }.to_not raise_error
        expect(probe.counter).to eq(1)
      end
    end

    describe '#translation_status' do
      it 'calculates the percent translated, etc for a commit' do
        status = file.translation_status
        expect(status).to be_a(TranslationStatus)
        expect(status.percent_translated(locale.code)).to eq(0.5)
      end
    end

    context 'with phrase storage granularity set to BRANCH' do
      let(:granularity) { Commits::PhraseStorageGranularity::BRANCH }

      describe '#file_uri' do
        it 'adds the git user, repo name, and branch name to the filename' do
          expect(file.file_uri).to eq(
            "#{repo_name}/#{git_user}/#{commit_log.branch_name}.txt"
          )
        end
      end

      it 'falls back to using the commit id if branch name is nil' do
        commit_log.branch_name = nil
        expect(file.file_uri).to eq("#{repo_name}/#{git_user}/#{commit_id}.txt")
      end
    end
  end

  describe '#translation_status' do
    it "returns a nil status if the file can't be found in smartling" do
      expect(configurator.smartling_api).to(
        receive(:status).and_raise(
          RuntimeError, not_found_error_message
        )
      )

      status = file.translation_status
      expect(status.phrase_count).to eq(0)
      expect(status.locale_counts.values.all? { |v| v == 0 }).to eq(true)
    end

    it 're-raises other smartling errors' do
      expect(configurator.smartling_api).to(
        receive(:status).and_raise(
          RuntimeError, 'foobarbaz'
        )
      )

      expect { file.translation_status }.to raise_error(RuntimeError)
    end
  end
end

# encoding: UTF-8

require 'spec_helper'

include Rosette::Core
include Rosette::DataStores
include Rosette::Tms::SmartlingTms

describe Repository do
  let(:repo_name) { 'single_commit' }
  let(:locale_code) { 'de-DE' }
  let(:locale) { repo_config.locales.first }
  let(:commit_id) { fixture.repo.git('rev-parse HEAD').strip }

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

  let(:repository) { Repository.new(configurator) }

  let(:phrase) do
    InMemoryDataStore::Phrase.create(key: 'foobar', meta_key: 'bar')
  end

  let(:two_phrases) do
    [
      InMemoryDataStore::Phrase.create(key: 'foobar', meta_key: 'bar'),
      InMemoryDataStore::Phrase.create(key: 'foobarbaz', meta_key: 'bar.baz')
    ]
  end

  let(:file) { SmartlingFile.new(configurator, commit_id) }

  let!(:commit_log) do
    InMemoryDataStore::CommitLog.create(
      status: PhraseStatus::FETCHED,
      repo_name: repo_name,
      commit_id: commit_id,
      phrase_count: 0,
      commit_datetime: nil,
      branch_name: 'refs/heads/origin/master'
    )
  end

  context 'with a translation memory' do
    let(:tmx_fixture) { TmxFixture.load('double') }

    before(:each) do
      allow(repository).to(
        receive(:download_memory).and_return(locale_code => tmx_fixture)
      )
    end

    describe '#lookup_translation' do
      it 'retrieves the correct translation for the given phrase' do
        repository.lookup_translation(locale, phrase).tap do |translation|
          expect(translation).to eq('foosbar')
        end
      end
    end

    describe '#lookup_translations' do
      it 'retrieves the correct translations for the given phrases' do
        repository.lookup_translations(locale, two_phrases).tap do |translations|
          expect(translations).to include('foosbar')
          expect(translations).to include('foosbarbeitsch')
        end
      end
    end
  end

  describe '#store_phrase' do
    it 'calls the smartling upload API' do
      expect(configurator.smartling_api).to receive(:upload).with(
        anything, file.file_uri, anything, anything
      )

      repository.store_phrase(phrase, commit_id)
    end
  end

  describe '#store_phrases' do
    it 'calls the smartling upload API' do
      expect(configurator.smartling_api).to receive(:upload).with(
        anything, file.file_uri, anything, anything
      )

      repository.store_phrases(two_phrases, commit_id)
    end
  end

  describe '#checksum_for' do
    it 'calculates the same checksum every time' do
      checksum = repository.checksum_for(locale, commit_id)
      repository.send(:memory).send(:checksums).clear  # clear checksum cache
      expect(checksum).to eq(repository.checksum_for(locale, commit_id))
    end
  end

  describe '#status' do
    it 'returns the status of the commit' do
      expect(configurator.smartling_api).to(
        receive(:status).and_return(
          'fileUri' => 'foo/bar/baz.txt',
          'stringCount' => 10,
          'completedStringCount' => 5
        )
      )

      status = repository.status(commit_id)
      expect(status).to be_a(TranslationStatus)
      expect(status.percent_translated(locale.code)).to eq(0.5)
    end
  end

  describe '#finalize' do
    it 'deletes the file from smartling' do
      expect(configurator.smartling_api).to receive(:delete).with(file.file_uri)
      repository.finalize(commit_id)
    end
  end
end

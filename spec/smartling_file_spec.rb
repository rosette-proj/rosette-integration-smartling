# encoding: UTF-8

require 'spec_helper'

include Rosette::Tms
include Rosette::Tms::SmartlingTms
include Rosette::Core
include Rosette::DataStores

describe SmartlingFile do
  let(:repo_name) { 'single_commit' }
  let(:locale_code) { 'de-DE' }
  let(:locale) { repo_config.locales.first }
  let(:commit_id) { fixture.repo.git('rev-parse HEAD').strip }
  let(:git_user) { fixture.repo.git('config user.name').gsub(/[^\w]/, '') }

  let(:fixture) do
    load_repo_fixture(repo_name) do |config, repo_config|
      repo_config.add_locale(locale_code)
    end
  end

  let(:rosette_config) { fixture.config }
  let(:repo_config) { rosette_config.get_repo(repo_name) }

  let(:configurator) do
    SmartlingTms::Configurator.new(rosette_config, repo_config).tap do |tms_config|
      tms_config.set_serializer('test/test')
    end
  end

  let(:phrase) { InMemoryDataStore::Phrase.create(key: 'foobar', meta_key: 'foo.bar') }
  let(:file) { SmartlingFile.new(configurator, commit_id) }

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
  end

  describe '#translation_status' do
    it 'calculates the percent translated, etc for a commit' do
      status = file.translation_status
      expect(status).to be_a(TranslationStatus)
      expect(status.percent_translated(locale.code)).to eq(0.5)
    end
  end
end

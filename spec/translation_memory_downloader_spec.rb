# encoding: UTF-8

require 'spec_helper'

include Rosette::Tms
include Rosette::Tms::SmartlingTms

describe TranslationMemoryDownloader do
  let(:repo_name) { 'single_commit' }
  let(:locale_codes) { %w(de-DE fr-FR) }
  let(:commit_id) { fixture.repo.git('rev-parse HEAD').strip }

  let(:fixture) do
    load_repo_fixture(repo_name) do |config, repo_config|
      repo_config.add_locales(locale_codes)
      repo_config.use_tms('smartling') do |tms_config|
        tms_config.set_thread_pool_size(0)
        tms_config.set_serializer('test/test')
        tms_config.set_api_options(
          smartling_api_key: 'fakekey', smartling_project_id: 'fakeid'
        )
      end
    end
  end

  let(:rosette_config) { fixture.config }
  let(:repo_config) { rosette_config.get_repo(repo_name) }

  let(:configurator) do
    repo_config.tms.configurator
  end

  let(:downloader) { TranslationMemoryDownloader.new(configurator) }
  let(:file) { SmartlingFile.new(configurator, commit_id) }

  describe '#build' do
    it 'downloads the translation memory for each locale' do
      locale_codes.each do |locale_code|
        uri = "https://api.smartling.com/v1/translations/download?apiKey=fakekey&projectId=fakeid&locale=#{locale_code}&format=TMX&dataSet=published"

        expect(RestClient).to(
          receive(:get).with(uri).and_return(
            RestClient::Response.create(
              "tmx contents for #{locale_code}", nil, nil, nil
            )
          )
        )
      end

      expect(downloader.build).to eq({
        'de-DE' => 'tmx contents for de-DE',
        'fr-FR' => 'tmx contents for fr-FR'
      })
    end
  end
end

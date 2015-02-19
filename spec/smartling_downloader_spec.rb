# encoding: UTF-8

require 'spec_helper'

include Rosette::Integrations

describe SmartlingIntegration::SmartlingDownloader do
  let(:downloader) { SmartlingIntegration::SmartlingDownloader }
  let(:smartling_api) { double(:api) }
  let(:file_uri) { 'path/to/fake.yml' }
  let(:locale) { Rosette::Core::Locale.parse('de-DE') }

  class RaisingApi
    def initialize(text_to_include)
      @errors_raised = 0
      @text_to_include = text_to_include
    end

    def download(file_uri, options)
      if @errors_raised == 0
        @errors_raised += 1
        raise RuntimeError, "Uh oh #{@text_to_include}, so sad"
      else
        :success
      end
    end
  end

  describe 'self#download_file' do
    it 'downloads the file' do
      expect(smartling_api).to(
        receive(:download)
          .with(file_uri, locale: locale.code)
          .and_return(:success)
      )

      response = downloader.download_file(smartling_api, file_uri, locale)
      expect(response).to eq(:success)
    end

    it 'retries if the resource is locked' do
      raising_api = RaisingApi.new('RESOURCE_LOCKED')
      response = downloader.download_file(raising_api, file_uri, locale)
      expect(response).to eq(:success)
    end

    it 'retries if the resource fails smartling validation' do
      raising_api = RaisingApi.new('VALIDATION_ERROR')
      response = downloader.download_file(raising_api, file_uri, locale)
      expect(response).to eq(:success)
    end

    it 'retries on any other exception' do
      raising_api = RaisingApi.new('foo')
      response = downloader.download_file(raising_api, file_uri, locale)
      expect(response).to eq(:success)
    end
  end
end

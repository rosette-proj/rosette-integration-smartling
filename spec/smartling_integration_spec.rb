# encoding: UTF-8

require 'spec_helper'

include Rosette::Integrations

describe SmartlingIntegration do
  let(:repo_name) { 'my_repo' }
  let(:configuration) { SmartlingIntegration::Configurator.new }
  let(:integration) { SmartlingIntegration.new(configuration) }

  describe 'configure' do
    it 'yields a configurator' do
      SmartlingIntegration.configure do |config|
        expect(config).to be_a(SmartlingIntegration::Configurator)
        expect(config).to respond_to(:set_serializer)
        expect(config).to respond_to(:set_api_options)
      end
    end
  end

  describe '#integrates_with?' do
    it 'only returns true if passed an instance of RepoConfig' do
      repo_config = Rosette::Core::RepoConfig.new(repo_name)
      expect(integration.integrates_with?(repo_config)).to be(true)
    end

    it 'returns false if passed an unintegratable object' do
      expect(integration.integrates_with?('foo')).to be(false)
    end
  end
end

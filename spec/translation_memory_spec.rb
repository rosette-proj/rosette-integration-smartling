# encoding: UTF-8

require 'spec_helper'

include Rosette::Integrations
include Rosette::DataStores

describe SmartlingIntegration::TranslationMemory do
  let(:locale) { Rosette::Core::Locale.parse('de-DE') }
  let(:meta_key) { 'teapot' }
  let(:phrase) do
    InMemoryDataStore::Phrase.create(
      key: "I'm a little teapot"
    )
  end

  let(:memory) do
    SmartlingIntegration::TranslationMemory.new(
      locale.code => { meta_key => phrase }
    )
  end

  describe '#translation_for' do
    it 'returns the translation for the given locale and meta key' do
      trans = memory.translation_for(locale, meta_key)
      expect(trans).to eq(phrase.key)
    end
  end
end

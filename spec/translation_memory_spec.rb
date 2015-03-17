# encoding: UTF-8

require 'spec_helper'

include Rosette::Integrations
include Rosette::DataStores

describe SmartlingIntegration::TranslationMemory do
  let(:locale_code) { 'de-DE' }
  let(:locale) { repo_config.locales.first }
  let(:meta_key) { "en.#{meta_key_base}" }
  let(:meta_key_base) { 'teapot' }
  let(:key) { "I'm a little teapot" }
  let(:translation) { "Soy una tetera pequeña" }
  let(:repo_name) { 'test_repo' }
  let(:phrase) do
    InMemoryDataStore::Phrase.create(
      key: key, meta_key: meta_key_base
    )
  end

  let(:rosette_config) do
    Rosette.build_config do |config|
      config.use_datastore('in-memory')
      config.use_error_reporter(Rosette::Core::RaisingErrorReporter.new)
      config.add_repo(repo_name) do |repo_config|
        repo_config.add_locale(locale_code)
        repo_config.add_placeholder_regex(/%\{.+?\}/)
      end
    end
  end

  let(:repo_config) do
    rosette_config.get_repo(repo_name)
  end

  def wrap_placeholders(text)
    text.gsub(/(\{\d+\})/) { "<ph>#{$1}</ph>" }
  end

  let(:tmx_contents) do
    %Q{
      <tmx version="1.4">
        <body>
          <tu tuid="abc123" segtype="block">
            <prop type="x-smartling-string-variant">#{meta_key}</prop>
            <tuv xml:lang="en-US"><seg>#{wrap_placeholders(key)}</seg></tuv>
            <tuv xml:lang="de-DE"><seg>#{wrap_placeholders(translation)}</seg></tuv>
          </tu>
        </body>
      </tmx>
    }
  end

  let(:memory_hash) do
    SmartlingIntegration::SmartlingTmxParser.load(tmx_contents)
  end

  let(:memory) do
    SmartlingIntegration::TranslationMemory.new(
      { locale_code => memory_hash }, rosette_config, repo_config
    )
  end

  describe '#translation_for' do
    it 'returns the translation for the given locale and meta key' do
      trans = memory.translation_for(locale, phrase)
      expect(trans).to eq(translation)
    end

    context 'with a translation with a Smartling-style placeholder' do
      let(:key) { "Hello there %{name}" }
      let(:translation) { "Hola {0}" }

      it 'replaces the Smartling-style placeholder' do
        trans = memory.translation_for(locale, phrase)
        expect(trans).to eq('Hola %{name}')
      end
    end

    context 'with a translation memory containing plurals' do
      let(:tmx_contents) do
        %Q{
          <tmx version="1.4">
            <body>
              <tu tuid="abc123" segtype="block">
                <prop type="x-smartling-string-variant">#{meta_key}.one</prop>
                <tuv xml:lang="en-US"><seg>DIY singular</seg></tuv>
                <tuv xml:lang="de-DE"><seg>DIY german singular</seg></tuv>
              </tu>
              <tu tuid="def456" segtype="block">
                <prop type="x-smartling-string-variant">#{meta_key}.other</prop>
                <tuv xml:lang="en-US"><seg>DIY plural</seg></tuv>
                <tuv xml:lang="de-DE"><seg>DIY german plural</seg></tuv>
              </tu>
              <tu tuid="ghi789[one]" segtype="block">
                <prop type="x-smartling-string-variant">#{meta_key}</prop>
                <tuv xml:lang="en-US"><seg>Smartling singular</seg></tuv>
                <tuv xml:lang="de-DE"><seg>Smartling german singular</seg></tuv>
              </tu>
              <tu tuid="ghi789[other]" segtype="block">
                <prop type="x-smartling-string-variant">#{meta_key}</prop>
                <tuv xml:lang="en-US"><seg>Smartling plural</seg></tuv>
                <tuv xml:lang="de-DE"><seg>Smartling german plural</seg></tuv>
              </tu>
            </body>
          </tmx>
        }
      end

      it 'defaults to smartling-style plurals' do
        phrase = InMemoryDataStore::Phrase.create(
          key: 'fakefake', meta_key: "#{meta_key_base}.one"
        )

        trans = memory.translation_for(locale, phrase)
        expect(trans).to eq('Smartling german singular')

        phrase.meta_key = "#{meta_key_base}.other"
        trans = memory.translation_for(locale, phrase)
        expect(trans).to eq('Smartling german plural')
      end

      it 'returns DIY (do-it-yourself) plurals if no smartling plurals exist' do
        # first, delete the smartling-style plurals
        memory_hash.delete(meta_key_base)

        phrase = InMemoryDataStore::Phrase.create(
          key: 'fakefake', meta_key: "#{meta_key_base}.one"
        )

        trans = memory.translation_for(locale, phrase)
        expect(trans).to eq('DIY german singular')

        phrase.meta_key = "#{meta_key_base}.other"
        trans = memory.translation_for(locale, phrase)
        expect(trans).to eq('DIY german plural')
      end
    end
  end
end

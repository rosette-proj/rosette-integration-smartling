# encoding: UTF-8

require 'spec_helper'

include Rosette::Tms::SmartlingTms
include Rosette::DataStores

describe TranslationMemory do
  let(:locale_code) { 'de-DE' }
  let(:locale) { repo_config.locales.first }
  let(:meta_key) { "en.#{meta_key_base}" }
  let(:meta_key_base) { 'teapot' }
  let(:key) { "I'm a little teapot" }
  let(:translation) { "Soy una tetera pequeña" }
  let(:repo_name) { 'single_commit' }
  let(:phrase) do
    InMemoryDataStore::Phrase.create(
      key: key, meta_key: meta_key_base
    )
  end

  let(:rosette_config) { fixture.config }

  let(:fixture) do
    load_repo_fixture(repo_name) do |config, repo_config|
      config.use_datastore('in-memory')
      config.use_error_reporter(Rosette::Core::RaisingErrorReporter.new)
      config.add_repo(repo_name) do |repo_config|
        repo_config.add_locale(locale_code)
        repo_config.add_placeholder_regex(/%\{.+?\}/)
        repo_config.use_tms('smartling')
      end
    end
  end

  let(:repo_config) do
    rosette_config.get_repo(repo_name)
  end

  let(:configurator) { Configurator.new(rosette_config, repo_config) }

  let(:tmx_contents) do
    TmxFixture.load('single', {
      meta_key: meta_key, key: key, translation: translation
    })
  end

  let(:memory_hash) do
    SmartlingTmxParser.load(tmx_contents)
  end

  let(:memory) do
    TranslationMemory.new(
      { locale_code => memory_hash }, configurator
    )
  end

  describe '#checksum_for' do
    let(:tmx_contents) { TmxFixture.load('double') }

    it 'returns the same checksum' do
      expect(memory.checksum_for(locale)).to eq(memory.checksum_for(locale))

      second_memory = TranslationMemory.new(
        { locale_code => memory_hash }, configurator
      )

      expect(second_memory.checksum_for(locale)).to(
        eq(second_memory.checksum_for(locale))
      )

      expect(memory.checksum_for(locale)).to(
        eq(second_memory.checksum_for(locale))
      )
    end
  end

  describe '#translation_for' do
    it 'returns the translation for the given locale and meta key' do
      trans = memory.translation_for(locale, phrase)
      expect(trans).to eq(translation)
    end

    context 'with a translation with a Smartling-style placeholder' do
      let(:key) { 'Hello there {0}' }
      let(:translation) { 'Hola {0}' }

      it 'replaces the Smartling-style placeholder' do
        phrase.key = 'Hello there %{name}'
        trans = memory.translation_for(locale, phrase)
        expect(trans).to eq('Hola %{name}')
      end
    end

    context 'with a translation containing multiple Smartling-style placeholders' do
      let(:key) { 'I like {0}, {1}, and {2}' }
      let(:translation) { 'Me gustan los {2}, {0}, and {1}'}

      it 'correctly associates Smartling-style placeholders with named ones' do
        phrase.key = 'I like %{apples}, %{bananas}, and %{peaches}'
        trans = memory.translation_for(locale, phrase)
        expect(trans).to eq('Me gustan los %{peaches}, %{apples}, and %{bananas}')
      end
    end

    context 'with a translation memory containing plurals' do
      let(:tmx_contents) { TmxFixture.load('plurals', meta_key: meta_key) }

      it 'defaults to smartling-style plurals' do
        phrase = InMemoryDataStore::Phrase.create(
          key: 'Smartling singular', meta_key: "#{meta_key_base}.one"
        )

        trans = memory.translation_for(locale, phrase)
        expect(trans).to eq('Smartling german singular')

        phrase.meta_key = "#{meta_key_base}.other"
        phrase.key = 'Smartling plural'
        trans = memory.translation_for(locale, phrase)
        expect(trans).to eq('Smartling german plural')
      end

      it 'returns DIY (do-it-yourself) plurals if no smartling plurals exist' do
        # first, delete the smartling-style plurals
        memory_hash.delete(meta_key_base)

        phrase = InMemoryDataStore::Phrase.create(
          key: 'DIY singular', meta_key: "#{meta_key_base}.one"
        )

        trans = memory.translation_for(locale, phrase)
        expect(trans).to eq('DIY german singular')

        phrase.meta_key = "#{meta_key_base}.other"
        phrase.key = 'DIY plural'
        trans = memory.translation_for(locale, phrase)
        expect(trans).to eq('DIY german plural')
      end
    end

    context 'with a translation memory containing duplicate meta keys' do
      let(:tmx_contents) do
        TmxFixture.load('duplicate_meta_keys', meta_key: meta_key)
      end

      it 'returns the correct translation using the phrase key to disambiguate' do
        phrase = InMemoryDataStore::Phrase.create(
          key: 'first value', meta_key: "#{meta_key_base}"
        )

        trans = memory.translation_for(locale, phrase)
        expect(trans).to eq('first value german')

        phrase.key = 'second value'
        trans = memory.translation_for(locale, phrase)
        expect(trans).to eq('second value german')
      end

      it 'returns the first exact meta key match if no key matches' do
        phrase = InMemoryDataStore::Phrase.create(
          key: 'foofoofoo', meta_key: "#{meta_key_base}"
        )

        trans = memory.translation_for(locale, phrase)
        expect(trans).to eq('first value german')
      end

      it 'returns nil if no match' do
        phrase = InMemoryDataStore::Phrase.create(
          key: 'foofoofoo', meta_key: "i.dont.exist"
        )

        trans = memory.translation_for(locale, phrase)
        expect(trans).to be_nil
      end
    end

    context 'with a translation memory containing non-normalized text' do
      let(:tmx_contents) do
        TmxFixture.load('single', {
          key: [101, 115, 112, 97, 110, 771, 111, 108].pack("U*"),  # español
          meta_key: meta_key,
          translation: 'spanish'
        })
      end

      it 'normalizes the string when comparing' do
        phrase = InMemoryDataStore::Phrase.create(
          key: [101, 115, 112, 97, 241, 111, 108].pack("U*"),
          meta_key: "#{meta_key_base}"
        )

        trans = memory.translation_for(locale, phrase)
        expect(trans).to eq('spanish')
      end
    end
  end
end

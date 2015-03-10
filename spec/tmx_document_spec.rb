# encoding: UTF-8

require 'spec_helper'

include Rosette::Integrations

describe SmartlingIntegration::TmxDocument do
  let(:locale_code) { 'de-DE' }
  let(:result_hash) { {} }

  let(:document) do
    SmartlingIntegration::TmxDocument.new(locale_code) do |meta_key, key|
      result_hash[meta_key] = key
    end
  end

  let(:parser) do
    Nokogiri::XML::SAX::Parser.new(document)
  end

  it 'identifies keys and meta keys' do
    tmx_contents = %Q{
      <tmx version="1.4">
        <body>
          <tu tuid="79b371014a8382a3b6efb86ec6ea97d9" segtype="block">
            <prop type="x-segment-id">0</prop>
            <prop type="smartling_string_variant">six.hours</prop>
            <tuv xml:lang="en-US"><seg>6 hours</seg></tuv>
            <tuv xml:lang="de-DE"><seg>6 Stunden</seg></tuv>
          </tu>
        </body>
      </tmx>
    }

    parser.parse(tmx_contents)
    expect(result_hash).to eq(
      'six.hours' => '6 Stunden'
    )
  end

  it 'falls back to the tuid if no meta key exists' do
    tmx_contents = %Q{
      <tmx version="1.4">
        <body>
          <tu tuid="79b371014a8382a3b6efb86ec6ea97d9" segtype="block">
            <prop type="x-segment-id">0</prop>
            <tuv xml:lang="en-US"><seg>6 hours</seg></tuv>
            <tuv xml:lang="de-DE"><seg>6 Stunden</seg></tuv>
          </tu>
        </body>
      </tmx>
    }

    parser.parse(tmx_contents)
    expect(result_hash).to eq(
      '79b371014a8382a3b6efb86ec6ea97d9' => '6 Stunden'
    )
  end

  it 'does not return strings that have a segment id greater than zero' do
    tmx_contents = %Q{
      <tmx version="1.4">
        <body>
          <tu tuid="79b371014a8382a3b6efb86ec6ea97d9" segtype="block">
            <prop type="x-segment-id">1</prop>
            <tuv xml:lang="en-US"><seg>6 hours</seg></tuv>
            <tuv xml:lang="de-DE"><seg>6 Stunden</seg></tuv>
          </tu>
        </body>
      </tmx>
    }

    parser.parse(tmx_contents)
    expect(result_hash).to eq({})
  end

  context 'with a different locale' do
    let(:locale_code) { 'fr-FR' }

    it 'does not return strings in the wrong locale' do
      tmx_contents = %Q{
        <tmx version="1.4">
          <body>
            <tu tuid="79b371014a8382a3b6efb86ec6ea97d9" segtype="block">
              <prop type="x-segment-id">0</prop>
              <tuv xml:lang="en-US"><seg>6 hours</seg></tuv>
              <tuv xml:lang="de-DE"><seg>6 Stunden</seg></tuv>
            </tu>
          </body>
        </tmx>
      }

      parser.parse(tmx_contents)
      expect(result_hash).to eq({})
    end
  end
end

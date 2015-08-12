# encoding: UTF-8

require 'spec_helper'

include Rosette::Tms

describe SmartlingTms::PlaceholderScanner do
  let(:regexes) { [] }
  let(:html_attributes) { true }
  let(:scanner) do
    SmartlingTms::PlaceholderScanner.new(regexes, html_attributes)
  end

  it 'identifies html attributes by default' do
    phs = scanner.scan('<a href="foo.com" target="_blank">blarg</a>')
    expect(phs).to eq(%w(foo.com _blank))
  end

  it 'identifies special smartling "ph" placeholders' do
    phs = scanner.scan('foo {ph:{0}} bar')
    expect(phs).to eq(%w({ph:{0}}))
  end

  it 'identifies special smartling "ph" placeholders in html attributes' do
    phs = scanner.scan('<a href="{ph:{0}}">blarg</a>')
    expect(phs).to eq(%w({ph:{0}}))
  end

  context 'without html attributes' do
    let(:html_attributes) { false }

    it 'does not identify html attributes if explicitly disabled' do
      phs = scanner.scan('<a href="foo.com" target="_blank">blarg</a>')
      expect(phs).to eq([])
    end

    it 'identifies smartling "ph" placeholders even when html is disabled' do
      phs = scanner.scan('<a href="{ph:{0}}">blarg</a>')
      expect(phs).to eq(%w({ph:{0}}))
    end
  end

  context 'with some regexes' do
    let(:regexes) { [/%\{.+?\}/, /\{%.+?%\}/] }  # ruby and liquid

    it 'identifies regex-based placeholders in the text' do
      phs = scanner.scan("I'm a %{little} {% teapot %}")
      expect(phs).to eq(['%{little}', '{% teapot %}'])
    end
  end
end

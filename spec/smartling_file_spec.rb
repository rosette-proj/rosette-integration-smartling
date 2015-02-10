# encoding: UTF-8

require 'spec_helper'

include Rosette::Integrations

describe SmartlingIntegration::SmartlingFile do
  let(:smartling_file) { SmartlingIntegration::SmartlingFile }

  describe 'self#from_api_response' do
    it 'extracts the repo name and commit id from the api response hash' do
      hash = create_file_entry(
        'repo_name' => 'awesome_repo',
        'commit_id' => 'abc123',
        'author' => 'KathrynJaneway'
      )

      smartling_file.from_api_response(hash).tap do |file|
        expect(file.repo_name).to eq('awesome_repo')
        expect(file.commit_id).to eq('abc123')
        expect(file.file_uri).to eq('awesome_repo/KathrynJaneway/abc123.yml')
      end
    end

    it 'identifies translated count and phrase count' do
      hash = create_file_entry('stringCount' => 5, 'completedStringCount' => 3)
      smartling_file.from_api_response(hash).tap do |file|
        expect(file.phrase_count).to eq(5)
        expect(file.translated_count).to eq(3)
      end
    end
  end

  describe 'self#list_from_api_response' do
    it 'creates a file list from the hash of files returned from the smartling api' do
      hash = create_file_list(3)
      list = smartling_file.list_from_api_response(hash)
      expect(list).to be_a(Array)
      expect(list.size).to eq(hash['fileList'].size)
    end
  end

  context 'with a file list' do
    let(:list) do
      smartling_file.list_from_api_response(create_file_list(3))
    end

    describe '#each' do
      it 'yields each file in the list' do
        index = 0

        list.each do |item|
          expect(list[index].commit_id).to eq(item.commit_id)
          index += 1
        end
      end
    end
  end
end

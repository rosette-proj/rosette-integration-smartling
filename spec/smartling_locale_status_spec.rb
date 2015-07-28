# encoding: UTF-8

require 'spec_helper'

include Rosette::Tms::SmartlingTms

describe SmartlingLocaleStatus do
  let(:smartling_file_status) { SmartlingLocaleStatus }

  describe 'self#from_api_response' do
    it 'extracts the repo name and commit id from the api response hash' do
      hash = create_file_entry(
        'repo_name' => 'awesome_repo',
        'ref' => 'abc123',
        'author' => 'KathrynJaneway'
      )

      smartling_file_status.from_api_response(hash).tap do |file|
        expect(file.repo_name).to eq('awesome_repo')
        expect(file.ref).to eq('abc123')
        expect(file.file_uri).to eq('awesome_repo/KathrynJaneway/abc123.yml')
      end
    end

    it 'extracts the repo name and branch name from the api response hash' do
      hash = create_file_entry(
        'repo_name' => 'awesome_repo',
        'ref' => 'refs/remotes/origin/my_branch',
        'author' => 'KathrynJaneway'
      )

      smartling_file_status.from_api_response(hash).tap do |file|
        expect(file.repo_name).to eq('awesome_repo')
        expect(file.ref).to eq('refs/remotes/origin/my_branch')
        expect(file.file_uri).to eq(
          'awesome_repo/KathrynJaneway/refs/remotes/origin/my_branch.yml'
        )
      end
    end

    it 'identifies translated count and phrase count' do
      hash = create_file_entry('stringCount' => 5, 'completedStringCount' => 3)
      smartling_file_status.from_api_response(hash).tap do |file|
        expect(file.phrase_count).to eq(5)
        expect(file.translated_count).to eq(3)
      end
    end
  end

  describe 'self#list_from_api_response' do
    it 'creates a file list from the hash of files returned from the smartling api' do
      hash = create_file_list(3)
      list = smartling_file_status.list_from_api_response(hash)
      expect(list).to be_a(Array)
      expect(list.size).to eq(hash['fileList'].size)
    end
  end
end

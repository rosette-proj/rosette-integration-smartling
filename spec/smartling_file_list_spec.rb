# encoding: UTF-8

require 'spec_helper'

include Rosette::Integrations

describe SmartlingIntegration::SmartlingFileList do
  let(:file_list) { SmartlingIntegration::SmartlingFileList }

  describe 'self#from_api_response' do
    it 'creates a file list from the hash of files returned from the smartling api' do
      hash = create_file_list(3)
      list = file_list.from_api_response(hash)
      expect(list).to be_a(file_list)
      expect(list.file_list.size).to eq(hash['fileList'].size)
    end
  end

  context 'with a file list' do
    let(:list) do
      file_list.from_api_response(create_file_list(3))
    end

    describe '#each' do
      it 'yields each file in the list' do
        index = 0

        list.each do |item|
          expect(list.file_list[index].commit_id).to eq(item.commit_id)
          index += 1
        end
      end
    end
  end
end

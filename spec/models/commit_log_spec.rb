# encoding: UTF-8

require 'spec_helper'

include Rosette::Integrations

describe Smartling::CommitLog do
  describe 'validations' do
    context "without a commit_id" do
      let(:commit_log) { build(:commit_log, commit_id: nil) }

      it 'fails validation' do
        expect(commit_log.save).to eq(false)
        expect(commit_log.errors[:commit_id]).to include("can't be blank")
      end
    end

    context 'with an invalid status' do
      let(:commit_log) { build(:commit_log, status: 'blah') }

      it 'fails validation' do
        expect(commit_log.save).to eq(false)
        expect(commit_log.errors[:status]).to include("is not included in the list")
      end
    end
  end
end

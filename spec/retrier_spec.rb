# encoding: UTF-8

require 'spec_helper'

include Rosette::Integrations

describe SmartlingIntegration::SmartlingApi do
  class RetryError < StandardError; end

  class RetryTracker
    attr_reader :count

    def initialize
      @count = 0
    end

    def increment
      @count += 1
    end
  end

  let(:retrier) { SmartlingIntegration::Retrier }
  let(:error) { RetryError }
  let(:tracker) { RetryTracker.new }
  let(:track_proc) do
    Proc.new { tracker.increment && raise(RetryError) }
  end

  it 'catches errors and retries the specified number of times' do
    expect do
      retrier.retry(times: 3, &track_proc)
        .on_error(RetryError)
        .execute
    end.to raise_error(RetryError)

    expect(tracker.count).to eq(3)
  end

  it 'by default retries 5 times' do
    expect do
      retrier.retry(&track_proc)
        .on_error(RetryError)
        .execute
    end.to raise_error(RetryError)

    expect(tracker.count).to eq(5)
  end

  it 'does not catch unexpected errors' do
    expect do
      retrier.retry(times: 3, &track_proc)
        .on_error(RuntimeError)
        .execute
    end.to raise_error(RetryError)

    expect(tracker.count).to eq(1)
  end

  it 'calls the block associated with the error' do
    sentinel = nil

    retrier.retry { raise(RetryError) unless sentinel }
      .on_error(RetryError) { sentinel = :hit }
      .execute

    expect(sentinel).to eq(:hit)
  end
end

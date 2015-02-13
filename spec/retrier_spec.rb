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
  let(:error_message) { "I'm a little teapot" }
  let(:track_proc) do
    Proc.new { tracker.increment && raise(RetryError, error_message) }
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

  it "re-raises errors if the message doesn't match" do
    expect do
      retrier.retry(times: 3, &track_proc)
        .on_error(StandardError, message: /FOOBAR/)
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

  it 'moves down the chain of errors' do
    sentinel = nil

    expect do
      retrier.retry(times: 3, &track_proc)
        .on_error(RetryError, message: /FOOBAR/)
        .on_error(StandardError) { sentinel = :hit }
        .execute
    end.to raise_error(RetryError)

    expect(sentinel).to eq(:hit)
  end

  it 'sleeps exponentially if asked to back off' do
    trier = retrier.retry(times: 3, &track_proc)
      .on_error(RetryError, backoff: true)

    3.times do |i|
      expect(trier).to receive(:sleep).with(2 ** i)
    end

    expect { trier.execute }.to raise_error(RetryError)
  end

  it 'sleeps an exponentially increasing number of seconds with the given base' do
    trier = retrier.retry(times: 3, &track_proc)
      .on_error(RetryError, backoff: true, base_sleep_seconds: 2)

    3.times do |i|
      expect(trier).to receive(:sleep).with(2 * (2 ** i))
    end

    expect { trier.execute }.to raise_error(RetryError)
  end
end

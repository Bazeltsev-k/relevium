# frozen_string_literal: true

require 'spec_helper'
require 'application_utilities/background_service'

class TestWorker
  def self.perform_in(_delay, _class, _attributes); end
end

class TestWorkerService < ApplicationUtilities::BackgroundService
  attr_reader :worker_attr, :worker_attr2
  worker_attributes :worker_attr, :worker_attr2

  def initialize(worker_attr, worker_attr2, options = nil)
    super({background: true, perform_in: 15}, TestWorker)
    @worker_attr = worker_attr
    @worker_attr2 = worker_attr2
  end
end

RSpec.describe ApplicationUtilities::BackgroundService do
  let(:allow_perform) { allow_any_instance_of(described_class).to receive(:perform) }

  it 'should initialize new instance of class' do
    expect(described_class.new({}, TestWorker).is_a?(described_class)).to be true
  end

  it 'should initialize new instance with arguments' do
    allow_perform
    expect(described_class).to receive(:new).with({test: 'test'}, TestWorker).and_call_original
    described_class.call({test: 'test'}, TestWorker)
  end

  it 'should call perform if no options given' do
    expect_any_instance_of(described_class).to receive(:perform)
    described_class.call({}, TestWorker)
  end

  it 'should setup worker if background options given' do
    expect(TestWorker).to receive(:perform_in).with(15, described_class)
    described_class.call({background: true, perform_in: 15}, TestWorker)
  end

  it 'should not setup worker if background option false' do
    expect(TestWorker).not_to receive(:perform_in)
    described_class.call({background: false, perform_in: 15}, TestWorker)
  end

  it 'should set worker with worker attributes' do
    expect(TestWorker).to receive(:perform_in).with(15, TestWorkerService, 'test', 'test2')
    TestWorkerService.call('test', 'test2')
  end
end

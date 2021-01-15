# frozen_string_literal: true

require 'spec_helper'
require 'application_utilities/service'

class TestListener < ApplicationUtilities::Service
  def initialize(test)
    @test = test
  end

  def on_ok
    test_function(@test)
  end

  def on_fail; end

  private

  def test_function(_); end
end

class TestListener2 < ApplicationUtilities::Service
  def initialize(test)
    @test = test
  end

  def on_ok
    test_function(@test)
  end

  def on_fail; end

  private

  def test_function(_); end
end

class TestService < ApplicationUtilities::Service
  set_listener ::TestListener, :ok, :on_ok
  set_listener ::TestListener2, :ok, :on_ok
  set_listener ::TestListener, :fail, :on_fail
  set_listener ::TestListener2, :fail, :on_fail

  def initialize(test)
    @test = test
  end

  def call
    return broadcast(:ok, @test) if @test == 'test'

    broadcast(:fail, @test)
  end
end

RSpec.describe ApplicationUtilities::Service do
  let(:allow_call) { allow_any_instance_of(described_class).to receive(:call) }

  it 'should create new instance of class' do
    instance = described_class.new
    expect(instance.is_a?(described_class)).to be true
  end

  it 'should create new instance with arguments in call method' do
    expect(described_class).to receive(:new).with('test').and_call_original
    allow_call
    described_class.call('test')
  end

  it 'should raise no method error on call' do
    expect { described_class.call('test') }.to raise_error(NoMethodError)
  end

  it 'should set local listeners' do
    expect(ApplicationUtilities::BlockRegistration).to receive(:new).and_call_original
    allow_call
    described_class.call('test') do |obj|
      obj.on(:ok) { 'test' }
    end
  end

  it 'should run local listeners' do
    TestService.call('test') do |obj|
      obj.on(:ok) { |test| @test = test }
    end
    expect(@test).not_to be_nil
  end

  it 'should run global listeners' do
    expect_any_instance_of(TestListener).to receive(:on_ok)
    expect_any_instance_of(TestListener2).to receive(:on_ok)
    TestService.call('test')
  end

  it 'should run global listeners on fail' do
    expect_any_instance_of(TestListener).to receive(:on_fail)
    expect_any_instance_of(TestListener2).to receive(:on_fail)
    TestService.call('error')
  end

  it 'should pass variables to global listeners' do
    expect_any_instance_of(TestListener).to receive(:test_function).with('test')
    expect_any_instance_of(TestListener2).to receive(:test_function).with('test')
    TestService.call('test')
  end
end

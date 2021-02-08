# frozen_string_literal: true

require 'spec_helper'
require 'relevium/form'
require 'ostruct'

class TestForm < Relevium::Form
  attribute :test, Integer
  attribute :test2, String, remove_from_hash: true
  attribute :test3, String, remove_from_hash: true
  attribute :bool, Boolean, remove_from_hash: true
  include_in_hash :combine_tests
  serialize_attributes :test2, :combine_tests, :test3

  validates :test, presence: true

  def combine_tests
    "#{test} - #{test2}"
  end

  def test3
    'qwe'
  end
end

RSpec.describe Relevium::Form do
  let(:hash) { { test: '12', test2: 'test2' } }
  let(:form) { TestForm.new(hash) }

  it 'should initialize new instance of form' do
    expect(form.is_a?(Relevium::Form)).to be true
  end

  it 'should set attributes types' do
    expect(form.test).to eq 12
    expect(form.test2).to eq 'test2'
  end

  it "should set nil if can't convert attributes" do
    expect(TestForm.new(test: 'test').test).to be_nil
  end

  it 'should work with boolean' do
    form_2 = TestForm.new(bool: 'false')
    expect(form_2.bool).to be false
  end

  it 'should produce hash of attributes' do
    result_hash = form.to_h
    expect(result_hash[:test]).to eq 12
    expect(result_hash[:test2]).to be_nil
    expect(result_hash[:combine_tests]).to eq '12 - test2'
  end

  it 'should validate form' do
    expect(form.valid?).to be true
    expect(TestForm.new(test2: 'asd').valid?).to be false
  end

  it 'should return errors messages' do
    form_2 = TestForm.new(test2: 'asd')
    form_2.validate
    expect(form_2.errors_to_string).to eq "Test can't be blank"
  end

  it 'should be able to set attributes' do
    expect(form.test).to eq 12
    form.set(:test, 15)
    expect(form.test).to eq 15
  end

  it 'should set hash' do
    expect(form.test).to eq 12
    expect(form.test2).to eq 'test2'
    form.set_attributes(test: 15, test2: 'qwe')
    expect(form.test).to eq 15
    expect(form.test2).to eq 'qwe'
  end

  it 'should serialize attributes' do
    form_2 = TestForm.new(test3: 'test3')
    result_hash = form_2.serialize
    expect(result_hash[:test2]).to be_nil
    expect(result_hash[:combine_tests]).to eq ' - '
    expect(result_hash[:test3]).to eq 'qwe'
  end

  it 'should serialize relation' do
    model1 = OpenStruct.new(attributes: { test: '12', test2: 'test2' })
    model2 = OpenStruct.new(attributes: { test2: 'test2', test3: 'T' })
    relation_arr = TestForm.serialize_relation([model1, model2])
    expect(relation_arr[0][:test]).to be nil
    expect(relation_arr[0][:combine_tests]).to eq '12 - test2'
    expect(relation_arr[0][:test3]).to eq 'qwe'
    expect(relation_arr[0][:test2]).to eq 'test2'
    expect(relation_arr[1][:combine_tests]).to eq ' - test2'
    expect(relation_arr[1][:test2]).to eq 'test2'
    expect(relation_arr[1][:test3]).to eq 'qwe'
  end

  it 'should build form from model' do
    form_2 = TestForm.from_model(OpenStruct.new(attributes: { test: '12', test2: 'test2' }))
    expect(form_2.test).to eq 12
    expect(form_2.test2).to eq 'test2'
  end
end

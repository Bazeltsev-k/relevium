# frozen_string_literal: true

require 'date'
require 'active_model'

module ApplicationUtilities
  class Form
    include ActiveModel::Model

    def initialize(hash)
      set_attributes(hash)
      self
    end

    def self.from_model(model)
      new(model.attributes)
    rescue StandardError => _e
      nil
    end

    def to_h
      hash = {}
      self.instance_variables.each do |var|
        var_name = var.to_s.delete('@')
        attribute = self.class.attributes.find { |attr| attr.attribute_name == var_name.to_sym }
        hash[var_name] = instance_variable_get(var) if attribute&.remove_from_hash == false
      end
      self.class.methods_for_hash.each do |method|
        hash[method] = self.send(method)
      end
      hash.default_proc = proc { |h, k| h.key?(k.to_s) ? h[k.to_s] : nil }
      hash
    end

    def serialize
      hash = {}
      self.class.attributes_to_serialize.each do |attribute|
        hash[attribute] = self.send(attribute) rescue instance_variable_get("@#{attribute}")
      end
      hash.default_proc = proc { |h, k| h.key?(k.to_s) ? h[k.to_s] : nil }
      hash
    end

    def set(name, value)
      attribute = self.class.attributes.find { |attr| attr.attribute_name.to_s == name.to_s }
      if attribute.present?
        set_attribute(attribute, value)
      else
        instance_variable_set("@#{name}", value)
      end
      self
    end

    def set_attributes(hash)
      hash.to_h.to_a.each do |attr_array|
        set(attr_array[0], attr_array[1])
      end
      self
    end

    def errors_to_string
      errors.full_messages.to_sentence
    end

    def self.i18n_scope
      :activerecord
    end

    private

    def set_attribute(attribute, value)
      instance_variable_set(attribute.name_to_instance_variable, attribute.normalized_value(value))
    end

    def self.attribute(attribute, type = nil, remove_from_hash: false)
      attributes << Attribute.new(attribute, type, remove_from_hash)
      self.class_eval { attr_reader attribute }
    end

    def self.attributes
      @attributes ||= Set.new
    end

    def self.include_in_hash(*methods)
      @methods_for_hash = methods
    end

    def self.methods_for_hash
      @methods_for_hash ||= []
    end

    def self.serialize_attributes(*attributes)
      @attributes_to_serialize = attributes
    end

    def self.attributes_to_serialize
      @attributes_to_serialize ||= []
    end

    def self.serialize_relation(relation)
      relation.map { |model| from_model(model).serialize }
    end

    class Boolean; end
  end

  class Attribute
    DATE_TYPES = [Date, Time, DateTime].freeze
    TRUE_VALUES = [true, 1, '1', 't', 'T', 'true', 'TRUE'].freeze

    attr_reader :attribute_name, :type, :remove_from_hash

    def initialize(attribute_name, type = nil, remove_from_hash = false)
      @attribute_name = attribute_name
      @type = type
      @remove_from_hash = remove_from_hash
    end

    def normalized_value(value)
      return nil if value.nil?
      return value unless type
      return value if value.is_a?(type)

      cast_value_to_type(value)
    rescue ArgumentError => _e
      nil
    end

    def cast_value_to_type(value)
      return TRUE_VALUES.include?(value) if type == ::ApplicationUtilities::Form::Boolean
      return method(type.to_s).call(value) unless DATE_TYPES.include?(type)

      value.send("to_#{type.to_s.underscore}")
    end

    def name_to_instance_variable
      "@#{attribute_name}"
    end
  end
end

# frozen_string_literal: true

require 'byebug'

module ApplicationUtilities
  class Service
    def self.call(*args)
      obj = new(*args)
      yield obj if block_given?
      obj.call
    end

    def initialize(*args); end

    def broadcast(name, *args)
      local_registrations.select { |registration| registration.listener == name }.first&.broadcast(*args)
      self.class.global_registrations.select { |registration| registration.message == name }
                                    &.each { |listener| listener.broadcast(*args) }
      self
    end

    def transaction(&block)
      ActiveRecord::Base.transaction(&block) if block_given?
    end

    def on(name, &block)
      local_registrations << BlockRegistration.new(name, block)
      self
    end

    def local_registrations
      @local_registrations ||= Set.new
    end

    def self.set_listener(klass, message, function_name)
      global_registrations << GlobalRegistration.new(klass, message, function_name)
    end

    def self.global_registrations
      @global_registrations ||= Set.new
    end

    def call
      raise NoMethodError
    end
  end

  class BlockRegistration
    attr_reader :listener, :message

    def initialize(listener, message)
      @listener = listener
      @message = message
    end

    def broadcast(*args)
      message.call(*args)
    end
  end

  class GlobalRegistration < BlockRegistration
    attr_reader :function

    def initialize(listener, message, function)
      super(listener, message)
      @function = function
    end

    def broadcast(*args)
      listener.new(*args).send(function)
    end

    def validate!
      return if [String, Symbol].include?(function.class)

      raise "Invalid function name. Expected symbol or string, got #{function.class}"
    end
  end
end

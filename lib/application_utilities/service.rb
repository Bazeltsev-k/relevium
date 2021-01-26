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

    def on(name, &block)
      local_registrations << BlockRegistration.new(name, block)
      self
    end

    private

    def broadcast(name, *args)
      set_off_local_listeners(name, *args)
      set_off_global_listeners(name, *args)
      self
    end

    def set_off_local_listeners(name, *args)
      local_registrations.select { |registration| registration.listener == name }.first&.broadcast(*args)
    end

    def set_off_global_listeners(name, *args)
      registrations = self.class.global_registrations.select { |registration| registration.message == name }
      registrations.each do |registration|
        next unless registration.condition.nil? || registration.condition.call(self)

        registration.args.nil? ? registration.broadcast(*args) : registration.broadcast(*get_args(*registration.args))
      end
    end

    def get_args(*args)
      args.map { |arg| instance_variable_get("@#{arg}") }
    end

    def transaction(&block)
      ActiveRecord::Base.transaction(&block) if block_given?
    end

    def local_registrations
      @local_registrations ||= Set.new
    end

    def self.set_listener(klass, message, options = {})
      global_registrations << GlobalRegistration.new(klass, message, options)
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
    attr_reader :function, :condition, :args

    def initialize(listener, message, options = {})
      super(listener, message)
      @function = options[:function] || 'call'
      @condition = options[:if]
      @args = options[:args]
    end

    def broadcast(*args)
      listener.new(*args).send(function)
    end

    def validate!
      raise 'Invalid function name for listener' unless [String, Symbol].include?(function.class)
      raise 'Invalid condition for listener' unless condition.is_a?(Proc)
    end
  end
end

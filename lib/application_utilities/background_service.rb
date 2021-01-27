# frozen_string_literal: true

require 'application_utilities/service'

module ApplicationUtilities
  class BackgroundService < Service
    attr_reader :options, :worker_class

    def initialize(options, worker_class)
      @options = options
      @worker_class = worker_class
    end

    def call
      return broadcast(:fail) unless valid?

      background? ? setup_worker : perform
    end

    private

    def perform
      NoMethodError
    end

    def self.worker_attributes(*attributes)
      @worker_attributes_array = attributes
    end

    def self.worker_attributes_array
      @worker_attributes_array ||= []
    end

    def fetch_worker_attributes
      self.class.worker_attributes_array.map do |worker_attribute|
        instance_variable_get("@#{worker_attribute}")
      end
    end

    def setup_worker
      worker_class.perform_in(delay, self.class, *fetch_worker_attributes)
    end

    def delay
      options[:perform_in] || 5.minutes
    end

    def background?
      !options[:background].nil? && options[:background]
    end

    def valid?
      true
    end
  end
end

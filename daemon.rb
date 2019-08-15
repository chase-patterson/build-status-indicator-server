require 'singleton'
require 'json'

require_relative 'pipeline.rb'
require_relative 'exceptions.rb'

module BuildStatusIndicator
  class Daemon
    include Singleton
  
    def initialize
      @pipelines = []
      @indicators = []
      @controllers = []
      @msg_callbacks = []
    end
  
    attr_reader :pipelines, :indicators, :controllers
  
    def add_pipeline props
      pipeline = Pipeline.new(props)
      @pipelines.push pipeline

      # Start polling

      return pipeline
    end

    def update_pipeline props
      pipeline = @pipelines.find do |pipeline|
        if props.include? 'id'
          pipeline.id == props['id']
        else
          raise BSIException, 'Must provide an ID to update pipeline'
        end
      end

      if pipeline.nil?
        raise BSIException, "Pipeline with given ID, not found"
      end

      # Stop polling

      pipeline.update props

      # Start polling
    end

    def remove_pipeline props
      pipeline = @pipelines.find do |pipeline|
        if props.include? 'id'
          pipeline.id == props['id']
        else
          raise BSIException, 'Must provide an ID to remove pipeline'
        end
      end

      # Stop polling

      @pipelines.delete pipeline
    end
  
    def on_msg &block
      @msg_callbacks.push block
    end
  
    def forget_msg_callback callback
      @msg_callbacks.delete callback
    end
  
    def emit_msg message
      @msg_callbacks.each do |callback|
        callback.call message
      end
    end
  end
end

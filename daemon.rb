require 'singleton'
require 'json'

require_relative 'pipeline.rb'

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
      @pipelines.push Pipeline.new(props)
    end

    def update_pipeline props
      pipeline = @pipelines.find do |pipeline|
        if props.include? 'id'
          pipeline.id == props['id']
        else
          throw 'Must provide an ID to update pipeline'
        end
      end

      if pipeline.nil?
        throw "Pipeline with given ID, not found"
      end

      # Stop polling

      if props.include? 'jenkins_project_url'
        pipeline.jenkins_project_url = props['jenkins_project_url']
      end

      # Start polling
    end

    def remove_pipeline props
      pipeline = @pipelines.find do |pipeline|
        if props.include? 'id'
          pipeline.id == props['id']
        else
          throw 'Must provide an ID to delete pipeline'
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

require 'singleton'
require 'json'
require 'mqtt'

require_relative 'pipeline.rb'
require_relative 'device.rb'
require_relative 'lightbulb.rb'
require_relative 'exceptions.rb'

module BuildStatusIndicator
  class Daemon
    include Singleton

    attr_reader :pipelines, :indicators, :controllers
  
    def initialize
      @mqtt_broker_addr = '10.254.10.93'

      @pipelines = []
      @indicators = []
      @controllers = []
      @msg_callbacks = []

      self.start_sub_zigbee2mqtt_log

      self.get_devices
    end

    def get_devices
      devices = []
      sub_client = nil

      sub_thread = Thread.new do
        sub_client = MQTT::Client.connect(@mqtt_broker_addr)
        topic, devices_json = sub_client.get 'zigbee2mqtt/bridge/config/devices'
        sub_client.disconnect

        device_props = JSON.parse devices_json

        device_ids = (device_props.select do |device|
          device.include? 'friendly_name'
        end).collect do |device|
          device['friendly_name']
        end

        devices = device_ids.collect do |device_id|
          Lightbulb.new device_id
        end

        self.update_devices devices
      end

      pub_thread = Thread.new do
        # Wait until our subscriber is really listening
        retries = 0
        while sub_client.nil? || !sub_client.connected?
          if retries > 50
            sub_thread.terminate
            sub_client.disconnect if !sub_client.nil?
            raise BSIException, "Timed-out waiting for subscriber"
          end
          sleep 0.1
          retries += 1
        end

        MQTT::Client.connect(@mqtt_broker_addr) do |c|
          c.publish 'zigbee2mqtt/bridge/config/devices/get', ""
        end
      end
    end

    def update_devices devices
      @indicators = devices
    end

    def start_sub_zigbee2mqtt_log
      if @zigbee2mqtt_log_thread.nil?
        @sub_zigbee2mqtt_log_thread = Thread.new do
          MQTT::Client.connect(@mqtt_broker_addr) do |c|
            c.get 'zigbee2mqtt/bridge/log' do |topic, message|
              puts "#{topic}: #{message}"
            end
          end
        end
      end
    end

    def stop_sub_zigbee2mqtt_log
      unless @zigbee2mqtt_log_thread.nil?
        @zigbee2mqtt_log_thread.terminate
        @zigbee2mqtt_log_thread = nil
      end
    end
  
    def add_pipeline props
      pipeline = Pipeline.new(props)
      @pipelines.push pipeline

      # Start polling

      return pipeline
    end

    def update_indicator props
      indicator = @indicators.find do |indicator|
        if props.include? 'id'
          indicator.id == props['id']
        else
          raise BSIException, 'Must provide an ID to update indicator'
        end
      end

      if indicator.nil?
        raise BSIException, "Indicator with given ID, not found"
      end

      if props.include? 'brightness'
        indicator.brightness = props['brightness']
      end

      if props.include? 'state'
        indicator.state = props['state']
      end
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

      if props.include? 'linked_indicators'
        indicators = @indicators.select do |indicator|
          props['linked_indicators'].include? indicator.id
        end

        props['linked_indicators'] = indicators
      end

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

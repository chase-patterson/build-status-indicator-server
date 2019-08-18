require_relative 'device.rb'

module BuildStatusIndicator
  class Lightbulb < Device
    attr_reader :state, :brightness

    def initialize id
      super
      @state = :off
      @brightness = 1
      @sub_thread = nil
      @sub_client = nil

      self.start_sub
    end

    def start_sub
      if @sub_thread.nil?
        @sub_thread = Thread.new do
          @sub_client = MQTT::Client.connect(@mqtt_broker_addr)
          @sub_client.get "zigbee2mqtt/#{@id}" do |topic, message|
            device_props = JSON.parse message
            puts "#{topic}: #{message}"

            if device_props.include? 'state'
              @state = device_props['state'] == 'ON' ? :on : :off
            end

            if device_props.include? 'brightness'
              @brightness = device_props['brightness'].to_i
            end
          end
        end
      end

      pub_thread = Thread.new do
        # Wait until our subscriber is really listening
        retries = 0
        while @sub_client.nil? || !@sub_client.connected?
          if retries > 50
            @sub_thread.terminate
            @sub_client.disconnect if !sub_client.nil?
            raise BSIException, "Timed-out waiting for subscriber"
          end
          sleep 0.1
          retries += 1
        end

        MQTT::Client.connect(@mqtt_broker_addr) do |c|
          c.publish "zigbee2mqtt/#{@id}/get", { 'state' => "", 'brightness' => ""}.to_json
        end
      end
    end

    def stop_sub
      @sub_client.disconnect
      @sub_thread.terminate
    end

    def brightness=(brightness)
      @brightness = brightness
      self.update_props
    end

    def state=(state)
      @state = state
      self.update_props
    end

    def update_props
      self.send_props({
        'state': @state == :on ? 'ON' : 'OFF',
        'brightness': @brightness.to_s
      })
    end
  end
end
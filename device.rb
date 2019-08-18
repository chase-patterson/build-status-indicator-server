require 'mqtt'
require 'json'

module BuildStatusIndicator
  class Device
    attr_reader :id

    def initialize id
      @mqtt_broker_addr = '192.168.43.185' #'10.254.10.93'
      @id = id
    end

    def send_props props
      MQTT::Client.connect(@mqtt_broker_addr) do |c|
        puts props.to_json
        c.publish "zigbee2mqtt/#{id}/set", props.to_json
      end
    end
  end
end
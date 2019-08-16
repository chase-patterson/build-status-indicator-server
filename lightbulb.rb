require_relative 'device.rb'

module BuildStatusIndicator
  class Lightbulb < Device
    attr_reader :state, :brightness

    def initialize id
      super
      @brightness = 1
      @state = :off
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
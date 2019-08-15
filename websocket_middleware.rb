require 'thin'
require 'rack'
require 'faye/websocket'
Faye::WebSocket.load_adapter('thin')

require_relative 'daemon.rb'

module BuildStatusIndicator
  class WebSocketMiddleware
    def initialize(app)
      @app = app
    end
  
    def call(env)
      if Faye::WebSocket.websocket?(env)
        ws = Faye::WebSocket.new(env)
        msg_handler = Proc.new { |msg| ws.send(msg) }
    
        ws.on :message do |event|
          ws.send(event.data)
        end
    
        ws.on :close do |event|
          Daemon.instance.forget_msg_callback msg_handler
          ws = nil
        end
  
        # Register callback to receive messages from daemon
        WebPositionerFrontend.instance.on_msg &msg_handler
    
        # Return async Rack response
        ws.rack_response
      else
        @app.call(env)
      end
    end
  end
end

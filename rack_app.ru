require 'rack/cors'

require_relative 'websocket_middleware.rb'
require_relative 'api_app.rb'

app = Rack::Builder.new do
  use Rack::Cors do
    allow do
      origins '*'
      resource '*',
        :headers => :any,
        :methods => [:get, :post, :put, :delete, :options]
    end
  end 
  use BuildStatusIndicator::WebSocketMiddleware
  map '/api' do
    run BuildStatusIndicator::APIApp.new
  end
end

run app

require 'json'
require 'timeout'

require_relative 'zmq_context.rb'
require_relative 'zmq_socket.rb'
require_relative 'positioner_frontend_streaming_interface.rb'
require_relative 'positioner_frontend_rest_interface.rb'
require_relative 'positioner_data_source_interface.rb'
require_relative 'dc_rotor.rb'

class PositionerDriver
  def initialize
    @rotor = DCRotor.instance

    @ds_queue_browse_mutex = Mutex.new
    @ds_queues = {}
    PositionerDataSourceInterface::browse do |mq_change|
      case mq_change[:type]
      when :add
        @ds_queue_browse_mutex.synchronize do
          @ds_queues[mq_change[:id]] = mq_change[:mq]
        end
      when :remove
        @ds_queues.delete mq_change[:id]
      end
    end

    @streaming_if = PositionerFrontendStreamingInterface.new 'Rotor Streaming Interface'
    @streaming_if.openProviderSocket
    @streaming_if.registerDNSSDService

    @rest_if = PositionerFrontendRESTInterface.new 'Rotor REST Interface'
    @rest_if.openProviderSocket
    @rest_if.registerDNSSDService

    @pub_thread = Thread.new do
      while true do
        @streaming_if.send_with_type 'rel_bearing', { 'rel_bearing' => @rotor.rel_bearing.to_s, 'target_rel_bearing' => @rotor.target_rel_bearing.to_s }.to_json
        sleep 0.5
      end
    end

    @rep_thread = Thread.new do
      while (msg = JSON.parse(@rest_if.receive)) do
        case msg['resource']
        when 'frontend-streaming-port'
          if msg['method'] == 'GET'
            @rest_if.send({ 'status' => 'success', 'data' => @streaming_if.port.to_s }.to_json)
          end
        when 'rel-bearing'
          if msg['method'] == 'PUT'
            @rest_if.send({ 'status' => 'success' }.to_json)
            @rotor.to_rel_bearing msg['data'].to_i
          end
        when 'data-sources-available'
          if msg['method'] == 'GET'
            data_sources = @ds_queues.collect do
              |id, mq|
              { 'hash' => mq.hash, 'name' => mq.name, 'address' => mq.address, 'port' => mq.port }
            end
            @rest_if.send({ 'status' => 'success', 'data' => data_sources }.to_json)
          end
        when 'data-source'
          if msg['method'] == 'GET'
            @rest_if.send({ 'status' => 'success', 'data' => @data_source }.to_json)
          end
        end
      end
    end

    @ds_sub_thread = Thread.new do
      last_rel_bearing = 0
      begin
        self.connect_data_source
        while (msg = Timeout::timeout(5) { @data_source.receive_with_type }) do
          cmd_rel_bearing = msg.to_i
          if cmd_rel_bearing != last_rel_bearing
            last_rel_bearing = cmd_rel_bearing
            @rotor.to_rel_bearing cmd_rel_bearing
          end
        end
      rescue Timeout::Error
        puts 'DS timed out'
        self.disconnect_data_source
        sleep 5
        retry
      end
    end
  end

  def connect_data_source
    @data_source = PositionerDataSourceInterface.new 'MFD Relative Bearing Queue', '10.10.60.185', 2345
    @data_source.openSubscriberSocket
  end

  def disconnect_data_source
    @data_source.closeSocket
  end
end

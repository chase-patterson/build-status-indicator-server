require 'rack'
require 'json'

require_relative 'daemon.rb'
require_relative 'exceptions.rb'

module BuildStatusIndicator
  class APIApp
    def call(env)
      req = Rack::Request.new(env)

      case req.path_info
      when "/pipelines"
        if req.get?
          pipelines = Daemon.instance.pipelines
          pipeline_props = pipelines.collect do |pipeline|
            {
              'id' => pipeline.id,
              'jenkins_project_url' => pipeline.jenkins_project_url,
              'indicator_associations' => pipeline.indicator_associations.collect do |assoc|
                { 'id': assoc['indicator'].id, 'status': assoc['status'] }
              end
            }
          end
          [200, { 'Content-Type' => 'application/json' }, [pipeline_props.to_json]]
        elsif req.post?
          pipeline = JSON.parse req.body.read
          pipeline_props = {
            'id' => Daemon.instance.add_pipeline(pipeline).id
          }
          [200, { 'Content-Type' => 'application/json' }, [pipeline_props.to_json]]
        elsif req.put?
          pipeline = JSON.parse req.body.read
          begin
            Daemon.instance.update_pipeline pipeline
            [200, { 'Content-Type' => 'application/json' }, [""]]
          rescue BSIException => e
            [400, { 'Content-Type' => 'application/json' }, [{ 'error' => e.message }.to_json]]
          end
        elsif req.delete?
          pipeline = JSON.parse req.body.read
          begin
            Daemon.instance.remove_pipeline pipeline
            [200, { 'Content-Type' => 'application/json' }, [""]]
          rescue BSIException => e
            [400, { 'Content-Type' => 'application/json' }, [{ 'error' => e.message }.to_json]]
          end
        end
      when "/indicators"
        if req.get?
          indicators = Daemon.instance.indicators
          indicator_props = indicators.collect do |indicator|
            { 'id': indicator.id,
              'state': indicator.state,
              'brightness': indicator.brightness }
          end
          [200, { 'Content-Type' => 'application/json' }, [indicator_props.to_json]]
        elsif req.put?
          indicator = JSON.parse req.body.read
          begin
            if indicator.include? 'state'
              case indicator['state']
              when 'on'
                indicator['state'] = :on
              when 'off'
                indicator['state'] = :off
              end
            end
            Daemon.instance.update_indicator indicator
            [200, { 'Content-Type' => 'application/json' }, [""]]
          rescue BSIException => e
            [400, { 'Content-Type' => 'application/json' }, [{ 'error' => e.message }.to_json]]
          end
        end
      when "/controllers"
        controllers = Daemon.instance.controllers
        [200, { 'Content-Type' => 'application/json' }, [controllers.to_json]]
      else
        [404, { 'Content-Type' => 'application/json' }, [{'code' => 404, 'message' => 'Not Found'}.to_json]]
      end
    end
  end
end

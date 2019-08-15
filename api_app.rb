require 'rack'
require 'json'

require_relative 'daemon.rb'

module BuildStatusIndicator
  class APIApp
    def call(env)
      req = Rack::Request.new(env)

      case req.path_info
      when "/pipelines"
        if req.get?
          pipelines = Daemon.instance.pipelines
          pipeline_props = pipelines.collect do |pipeline|
            { 'id' => pipeline.id,
              'jenkins_project_url' => pipeline.jenkins_project_url }
          end
          [200, { 'Content-Type' => 'application/json' }, [pipeline_props.to_json]]
        elsif req.post?
          pipeline = JSON.parse req.body.read
          Daemon.instance.add_pipeline pipeline
          [200, { 'Content-Type' => 'application/json' }, [""]]
        elsif req.put?
          pipeline = JSON.parse req.body.read
          Daemon.instance.update_pipeline pipeline
          [200, { 'Content-Type' => 'application/json' }, [""]]
        elsif req.delete?
          pipeline = JSON.parse req.body.read
          Daemon.instance.remove_pipeline pipeline
          [200, { 'Content-Type' => 'application/json' }, [""]]
        end
      when "/indicators"
        indicators = Daemon.instance.indicators
        [200, { 'Content-Type' => 'application/json' }, [indicators.to_json]]
      when "/controllers"
        controllers = Daemon.instance.controllers
        [200, { 'Content-Type' => 'application/json' }, [controllers.to_json]]
      else
        [404, { 'Content-Type' => 'application/json' }, [{'code' => 404, 'message' => 'Not Found'}.to_json]]
      end
    end
  end
end

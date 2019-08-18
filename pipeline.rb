require 'net/http'

module BuildStatusIndicator
  class Pipeline
    attr_reader :id, :jenkins_project_url, :indicator_associations

    def initialize props
      @id = self.hash.to_s

      if props.include? 'indicator_associations'
        @indicator_associations = props['indicator_associations']
      else
        @indicator_associations = []
      end

      if props.include? 'jenkins_project_url'
        @jenkins_project_url = props['jenkins_project_url']
      else
        @jenkins_project_url = ""
      end
    end

    def update props
      if props.include? 'jenkins_project_url'
        @jenkins_project_url = props['jenkins_project_url']
      end

      if props.include? 'indicator_associations'
        @indicator_associations = props['indicator_associations']
      end
    end

    def poll_jenkins
      loop do
        response = Net::HTTP.get URI(@jenkins_project_url + '/lastbuild/api/json')
        JSON.parse response
        sleep 10
      end
    end
  end
end

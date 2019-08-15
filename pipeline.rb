module BuildStatusIndicator
  class Pipeline
    attr_reader :id
    attr_accessor :jenkins_project_url

    def initialize props
      @id = self.hash.to_s
      if props.include? 'jenkins_project_url'
        @jenkins_project_url = props['jenkins_project_url']
      else
        @jenkins_project_url = ''
      end
    end

    def update props
    end
  end
end

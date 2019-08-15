module BuildStatusIndicator
  class BSIException < Exception
    attr_reader :message

    def initialize(message="Error")
      @message = message
    end
  end
end

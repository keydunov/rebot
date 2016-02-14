module Rebot
  class Configuration
    # Adapter to use, currently supported: slack_bot_server and relax
    attr_reader :adapter_options

    # Bot class
    attr_reader :bot_class

    attr_reader :queue

    # TODO: validate adapters
    def initialize
      @queue           = SlackBotServer::RedisQueue.new
      @adapter         = :slack_bot_server
      @adapter_options = {}
      @bot_class       = Rebot::Bot
    end

    def bot(bot_class = nil)
      if bot_class
        @bot_class = bot_class
      else
        @bot_class
      end
    end

    def adapter(adapter = nil, options = {})
      if adapter
        @adapter          = adapter
        @adapter_options  = options
      else
        @adapter
      end
    end

    def compile
      if self.adapter == :relax
        self.adapter_options[:relax_bots_pubsub]  ||= "relax_bots_pubsub"
        self.adapter_options[:relax_bots_key]     ||= "relax_bots_key"

        self.adapter_options[:incoming_queue] ||= "rebot_incoming_queue"
        self.adapter_options[:outgoing_queue] ||= "rebot_outgoing_queue"
      end

      self
    end
  end
end

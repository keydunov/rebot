# FIXME
module Rebot
  class Server
    def self.setup(config)
      backend = init_backend(config)
      backend.on_add do |token|
        config.bot_class.new(token: token)
      end
      backend
    end

    def self.init_backend(config)
      if config.adapter == :slack_bot_server
        SlackBotServer.logger = Rebot.logger
        SlackBotServer::Server.new(queue: config.queue)
      elsif config.adapter == :relax
        Backends::Relax.new(config)
      else
        raise "Unknown server adapter #{configuration.adapter}"
      end
    end
  end
end

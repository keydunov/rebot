module Rebot
  module Backends
    class Relax
      def initialize(config)
        @queue = nil # TODO
        @bots = {}
        @add_proc = -> (token) { SlackBotServer::SimpleBot.new(token: token) }
        @running = false

        @relax_bots_pubsub  = config.adapter_options[:relax_bots_pubsub]
        @relax_bots_key     = config.adapter_options[:relax_bots_key]
        @relax_events_queue = config.adapter_options[:relax_events_queue]
      end

      def start
        EM.run do
          @running = true
          listen_for_relax_events
          listen_for_instructions if @queue
        end
      end

      def on_add(&block)
        @add_proc = block
      end

      def add_bot(token, team_id)
        bot = @add_proc.call(token, team_id)
        # TODO: Хранить хэш ботов не в памяти а в редисе
        if !@bots[bot.key]
          Rebot.logger.info "Adding bot #{bot}"
          @bots[bot.key.to_sym] = bot
          redis.multi do
            redis.hset(@relax_bots_key, bot.team_id, {team_id: bot.team_id, token: bot.token}.to_json)
            redis.publish(@relax_bots_pubsub, {type: 'team_added', team_id: bot.team_id}.to_json)
          end
        end
      rescue => e
        # TODO:
        raise e
      end

      private

      def listen_for_relax_events
        EM.add_periodic_timer(1) do
          begin
            queue_name, event_json = redis.blpop(@relax_events_queue)
            if queue_name == @relax_events_queue
              #event = Event.new(JSON.parse(event_json))
              event = JSON.parse(event_json)
              puts event
            end
          rescue => e
            # TODO
            raise e
          end
        end
      end

      def listen_for_instructions
        EM.add_periodic_timer(1) do
          begin
            next_message = queue.pop
            process_instruction(next_message) if next_message
          rescue => e
            # TODO
            raise e
          end
        end
      end

      def redis
        if uri = ENV['REDISTOGO_URL']
          redis_uri = URI.parse(uri)
        elsif uri = ENV['REDIS_URL']
          redis_uri = URI.parse(uri)
        else
          redis_uri = URI.parse("redis://localhost:6379")
        end

        @redis ||= Redis.new(url: redis_uri, db: 0)
      end
    end
  end
end

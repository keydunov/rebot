module Rebot
  module Backends
    class Relax
      def initialize(config)
        @queue = config.queue
        @bots = {}
        @add_proc = -> (token) { SlackBotServer::SimpleBot.new(token: token) }
        @running = false

        @bots_key       = config.adapter_options[:bots_key]
        @incoming_queue = config.adapter_options[:incoming_queue]
        @outgoing_queue = config.adapter_options[:outgoing_queue]
      end

      def start
        EM.run do
          @running = true
          listen_for_relax_events
          listen_for_instructions if @queue
          start_ticking

        end
      end

      def on_add(&block)
        @add_proc = block
      end

      def add_bot(token)
        if @bots[token.to_sym]
          Rebot.logger.warn "Attempt to add already added bot with token: #{token}"
        else
          bot = @add_proc.call(token)
          Rebot.logger.info "Adding bot with token: #{bot.key}"
          @bots[bot.key.to_sym] = bot
          unless redis.hexists(@bots_key, bot.token)
            redis.multi do
              redis.hset(@bots_key, bot.token, { token: bot.token }.to_json)
              redis.publish(@outgoing_queue, { type: 'bot_added', token: bot.token }.to_json)
            end
          end
        end
      rescue => e
        # TODO:
        raise e
      end

      def message(token, message)
        redis.publish(@outgoing_queue, { type: 'message', token: token, message: message }.to_json)
      end

      private

      def start_ticking
        EM.add_periodic_timer(1) do
          begin
            @bots.values.each { |b| b.convos.each { |convo| convo.tick } }
          rescue => e
            # TODO
            log_error(e)
          end
        end
      end

      def listen_for_relax_events
        EM.add_periodic_timer(0.1) do
          begin
            event_json = redis.lpop(@incoming_queue)
            if event_json
              event = JSON.parse(event_json)
              if bot = @bots[event['token'].to_sym]
                Rebot.logger.debug "Received message for bot: #{bot}: #{event}"
                event = normalize_event_format(event)
                bot.send(:run_callbacks, event['type'], event)
              end
            end
          rescue => e
            # TODO
            log_error(e)
          end
        end
      end

      def listen_for_instructions
        EM.add_periodic_timer(1) do
          begin
            next_message = @queue.pop
            process_instruction(next_message) if next_message
          rescue => e
            log_error(e)
            # TODO
          end
        end
      end

      def process_instruction(instruction)
        type, *args = instruction
        Rebot.logger.info("Received remote instruction: #{type} with arguments: #{args}")
        bot_key = args.shift
        if type.to_sym == :add_bot
          add_bot(bot_key, *args)
        else
          with_bot(bot_key) do |bot|
            case type.to_sym
            when :remove_bot
              remove_bot(bot_key)
            when :broadcast
              log "[#{bot_key}] broadcast: #{args}"
              bot.broadcast(*args)
            when :say
              Rebot.logger.info "[#{bot_key}] say: #{args}"
              bot.say(*args)
            when :say_to
              user_id, message_data = args
              log "[#{bot_key}] say_to: (#{user_id}) #{message_data}"
              bot.say_to(user_id, message_data)
            when :call
              method, method_args = args
              bot.call(method, method_args)
            else
              log unknown_command: instruction
              Rebot.logger.warn("Unknown command: #{instruction}")
            end
          end
        end
      end

      def with_bot(key)
        if bot = bot(key)
          yield bot
        else
          Rebot.logger.warn("Unknown bot: #{key}")
        end
      end

      def bot(key)
        @bots[key.to_sym]
      end

      def normalize_event_format(event)
        if event['event'] == 'mention' || event['event'] == 'direct_mention'
          event['event'] = 'mention'
        end

        if event['event'] == 'direct_message'
          event['event'] = 'dm'
        end
        event
      end

      def log_error(e)
        Rebot.logger.warn("Error in server: #{e} - #{e.message}")
        Rebot.logger.warn(e.backtrace.join("\n"))
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

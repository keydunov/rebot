module Rebot
  class Server
    attr_reader :queue

    def initialize(queue: SlackBotServer::LocalQueue.new)
      @queue = queue
      @bots = {}
      @new_token_proc = -> (token) { Rebot::BaseBot.new(token: token) }
      @running = false
    end

    def on_new_token(&block)
      @new_token_proc = block
    end

    def start
      EM.run do
        begin
          @running = true
          @bots.each { |key, bot| bot.start }
          add_timers
        rescue => e
          log_error(e)
        end
      end
    end

    def add_timers
      EM.add_periodic_timer(1) do
        next_message = queue.pop
        process_instruction(next_message) if next_message
      end
    end

    def add_bot(bot)
      # Do not add bot same bot twice
      return if @bots[bot.token].present?
      log "adding bot #{bot}"
      @bots[bot.token] = bot
      bot.start if @running
    end

    def add_token(token)
      bot = @new_token_proc.call(token)
      add_bot(bot) if bot
    rescue => e
      log_error(e)
    end

    def remove_bot(token)
      if (bot = @bots[token])
        bot.stop
        @bots.delete(token)
      end
    rescue => e
      log_error(e)
    end

    private

    def process_instruction(instruction)
      type, *args = instruction
      case type.to_sym
      when :add_token
        token = args.first
        log "got new token: '#{token}'"
        add_token(token)
      when :remove_bot
        token = args.first
        remove_bot(token)
      when :say
        token, message_data = args
        bot = @bots[token]
        bot.say(message_data)
      when :call
        token, method, method_args = args
        bot = @bots[token]
        bot.call(method, method_args)
      else
        log unknown_command: instruction
      end
    end

    def log(message)
      text = message.is_a?(String) ? message : message.inspect
      Rebot.logger.info(text)
    end

    def log_error(e)
      Rebot.logger.warn("Error in server: #{e} - #{e.message}")
      Rebot.logger.warn(e.backtrace.join("\n"))
    end
  end
end

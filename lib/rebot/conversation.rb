module Rebot
  class Conversation
    DEFAULT_TIMEOUT = 180 # set default timeout to 180 seconds (3 minutes)
    DEFAULT_TIMEOUT_MESSAGE = "We can pick this up later."
    DEFAULT_STOP_PATTERNS = ["^exit", "^stop", "^quit"]
    DEFAULT_STOP_MESSAGE  = "Ok. Done"

    attr_reader :data, :source_message, :bot

    def initialize(bot, source_message)
      @bot            = bot
      @source_message = source_message
      @data           = {}
      @handlers_stack = [[]]
      @messages       = []
      @sent           = []
      @last_active_at = Time.now
    end

    def stop_patterns(value = nil)
      if value
        if value.is_a?(String)
          @stop_patterns = value.split(",")
        elsif value.is_a?(Array)
          @stop_patterns = value
        else
          raise TypeError
        end
      else
        @stop_patterns ||= DEFAULT_STOP_PATTERNS
      end
    end

    def stop_message(value = nil)
      if value
        @stop_message = value
      else
        @stop_message ||= DEFAULT_STOP_MESSAGE
      end
    end

    def timeout(value = nil)
      if value
        @timeout = value
      else
        @timeout ||= DEFAULT_TIMEOUT
      end
    end

    def timeout_message(value = nil)
      if value
        @timeout_message = value
      else
        @timeout_message ||= DEFAULT_TIMEOUT_MESSAGE
      end
    end

    def start(block, *args)
      @status = :active
      instance_exec(*args, &block)
    end

    def matched_option(text)
      stack = @handlers_stack.last
      handler = stack.find do |o|
        if o[:pattern]
          @last_matched_data = o[:pattern].match(text)
        end
      end

      unless handler
        handler = stack.find { |o| o[:default] }
      end

      handler
    end

    def active?
      @status == :active
    end

    def tick
      return unless active?

      if @messages.any?
        message = @messages.shift
        @bot.say(message)
        @sent.push(message)
        @last_active_at = Time.now

        if action = message[:action]
          if action == 'stop'
            @status = :stopped
            @bot.conversation_ended(self)
          end
        end
      end

      if @messages.empty? && @handlers_stack.last.empty?
        @status = :completed
        @bot.conversation_ended(self)
      end

      if Time.now - @last_active_at > timeout
        # Keep it simple for now
        @status = :timeout
        @bot.say(text: timeout_message, channel: @source_message.channel)
        @bot.conversation_ended(self)
      end
    end

    def handle(message)
      @last_active_at = Time.now
      Rebot.logger.debug "Handling message in conversation: #{message.text}"

      if stop_patterns.any? { |sp| message.text.match(Regexp.new(sp, true)) }
        say(text: stop_message, action: "stop")
        return
      end

      if option = matched_option(message.text)
        @handlers_stack.push([])
        if option[:default]
          instance_exec(message.text, &option[:callback])
        else
          instance_exec(*@last_matched_data.captures, &option[:callback])
        end
      else
        # FIXME
        say(@sent.last) if @messages.empty?
      end
    end

    def say(message)
      if message.is_a?(String)
        message =  { text: message, channel: @source_message.channel }
      else
        message[:channel] = @source_message.channel
      end
      @messages.push(message)
    end

    def hears(pattern, meta = {}, &callback)
      pattern = Regexp.new(pattern, true) if pattern.is_a?(String)
      @handlers_stack.last.push(
        { pattern: pattern, callback: callback }.merge(meta)
      )
    end

    def repeat
      @handlers_stack.pop
    end

    def default( &callback)
      hears(nil, { default: true }, &callback)
    end

    # extract into Conversation::Helpers
    def time
      /\d{1,2}:\d{1,2}\s*(am|pm)/i
    end

    def anything
      /(.*)/i
    end

    def yes
      /^(yes|yea|yup|yep|ya|sure|ok|y|yeah|yah)/i
    end

    def no
      /^(no|nah|nope|n)/i
    end
  end
end

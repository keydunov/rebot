module Rebot
  class Bot < SlackBotServer::Bot
    def initialize(token:, key: nil)
      super
      @convos         = []
    end

    # SlackBotServer::Bot only supports calling this with options;
    # the equivalent would be `reply(text: text_or_options)`
    def reply(text_or_options)
      if text_or_options.is_a?(String)
        super(text: text_or_options)
      else
        super(text_or_options)
      end
    end

    # Allow to not specify text option
    # Usefull for sending attachments only
    def say(options)
      options[:text] ||= ""
      super(options)
    end

    def start
      super

      EM.add_periodic_timer(1) do
        @convos.each { |convo| convo.tick }
      end
    end

    def start_conversation(name = nil, *args, &block)
      if name
        convo_block = Rebot.find_conversation(name)
      elsif block_given?
        convo_block = block
      else
        raise "Pass registered conversation name or block"
      end

      convo = Conversation.new(self, @last_received_message)
      @convos.push(convo)
      convo.start(convo_block, *args)
      Rebot.logger.debug "> [Start] Conversation with #{convo.source_message.user} in #{convo.source_message.channel}"
    end

    def conversation_ended(convo)
      @convos.delete(convo)
      Rebot.logger.debug "> [End] Conversation with #{convo.source_message.user} in #{convo.source_message.channel}"
    end

    class << self
      def hears(pattern, &block)
        callback = Proc.new do |message|
          pattern = pattern.is_a?(String) ? Regexp.new(pattern, true) : pattern
          if match_data = pattern.match(message.text)
            debug "I heard #{pattern}"
            instance_exec(message, *match_data.captures, &block)
            false
          end
        end

        on(:dm, &callback)
        on(:mention, &callback)
      end

      def afters
        @afters ||= []
      end

      def befores
        @befores ||= []
      end

      def after(&block)
        afters.push(block)
      end

      def before(&block)
        befores.push(block)
      end
    end

    private

    on(:message) do |data|
      unless ignorable_slack_event?(data)
        message = Message.new(data, self)
        @last_received_message = message

        self.class.befores.each { |c| instance_exec(message, &c) }

        if convo = find_conversation(message)
          convo.handle(message)
        else
          run_callbacks(message.event, message)
        end

        self.class.afters.each { |c| instance_exec(message, &c) }
      end
    end

    def ignorable_slack_event?(data)
      bot_message?(data) || data['text'].nil?
    end

    def find_conversation(message)
      @convos.detect do |convo|
        convo.active? &&
        convo.source_message.channel == message.channel &&
        convo.source_message.user == message.user
      end
    end
  end
end

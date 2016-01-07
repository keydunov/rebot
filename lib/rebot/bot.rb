module Rebot
  class Bot
    attr_reader :token, :identity

    class InvalidToken < RuntimeError; end

    class Identity < Struct.new(:name, :id); end

    def initialize(token:)
      @token = token
      @identity = nil
      @api = ::Slack::Client.new(token: @token)

      @im_channel_ids = []
      @channel_ids    = []
      @group_ids      = []

      @message_count  = 0

      @ims            = []

      @convos         = []

      @connected = false
      @running = false
    end

    def say(message)
      @message_count += 1
      slack_message = {
        :id       => @message_count,
        :type     => "message",

        :channel      => message[:channel],
        :text         => message[:text] || "", # slack-web-api gem does not allow nil for text,
        :username     => message[:username],
        :parse        => message[:parse],
        :link_names   => message[:link_names],
        :attachments  => (message[:attachments] ? JSON.dump(message[:attachments]) : nil),
        :unfurl_links => message[:unfurl_links],
        :unfurl_media => message[:unfurl_media],
        :icon_url     => message[:icon_url],
        :icon_emoji   => message[:icon_emoji],
        :as_user      => message[:as_user] || true
      }

      #if (message[:icon_url] || message[:icon_emoji] || message[:username] )
      #  slack_message[:as_user] = false
      #else
      #  slack_message[:as_user] = message[:as_user] || true
      #end

      # These options are not supported by the RTM
      # so if they are specified, we use the web API to send messages.
      if slack_message[:attachments] || slack_message[:icon_emoji] || slack_message[:username] || slack_message[:icon_url]
        @api.chat_postMessage(slack_message)
      else
        @ws.send(JSON.dump(slack_message))
      end
    end

    def typing
      @message_count += 1
      @ws.send(JSON.dump(channel: @last_received_message.channel, id: @message_count, type: "typing"))
    end

    def reply(text_or_options)
      channel = @last_received_message.channel

      if text_or_options.is_a?(String)
        options = { channel: channel, text: text_or_options }
      elsif text_or_options.is_a?(Hash)
        options = text_or_options.merge(channel: channel)
      else
        raise "unreachable"
      end

      say(options)
    end

    def call(method, args)
      args.symbolize_keys!
      @api.send(method, args)
    end

    def start
      unless auth_test['ok']
        log "Error connecting bot (token: #{token}) to Slack: #{auth_test}"
        return
      end

      # TODO: it should be async
      rtm_start = @api.post('rtm.start')
      @identitiy = Identity.new(rtm_start['self']['name'], rtm_start['self']['id'])
      @ws = Faye::WebSocket::Client.new(rtm_start['url'], nil, ping: 60)

      @running = true
      @ws.on :open do |event|
        @connected = true
        log "connected to '#{team}'"
        load_im_channels
        load_channels
      end

      @ws.on :message do |event|
        begin
          debug event.data
          handle_event(event)
        rescue => e
          log error: e
          log backtrace: e.backtrace
          Rollbar.error(e)
        end
      end

      @ws.on :close do |event|
        log "disconnected"
        @connected = false
        @auth_test = nil
        if @running
          start
        end
      end

      EM.add_periodic_timer(1) do
        @convos.each { |convo| convo.tick }
      end
    end

    def stop
      log "closing connection"
      @running = false
      @ws.close
      log "closed"
    end

    def connected?
      @connected
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
    end

    def conversation_ended(convo)
      @convos.delete(convo)
    end

    class << self
      def callbacks_for(type)
        callbacks = @callbacks[type.to_sym] || []
        if superclass.respond_to?(:callbacks_for)
          callbacks += superclass.callbacks_for(type)
        end
        callbacks
      end

      def on(type, &block)
        @callbacks ||= {}
        @callbacks[type.to_sym] ||= []
        @callbacks[type.to_sym] << block
      end

      def hears(pattern, &block)
        callback = Proc.new do |message|
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

    on :im_created do |data|
      channel_id = data['channel']['id']
      log "Adding new IM channel: #{channel_id}"
      @im_channel_ids << channel_id
    end

    on :channel_joined do |data|
      channel_id = data['channel']['id']
      log "Adding new channel: #{channel_id}"
      @channel_ids << channel_id
    end

    on :channel_left do |data|
      channel_id = data['channel']
      log "Removing channel: #{channel_id}"
      @channel_ids.delete(channel_id)
    end

    def to_s
      "<#{self.class.name} token:#{token}>"
    end

    private

    def handle_event(event)
      data = JSON.parse(event.data)

      # this is a confirmation of something we sent.
      return unless data['ok'].nil?

      if data['type'] == 'message'
        return if data['user'] == auth_test['user_id']

        # Ignore messages from slackbot
        return if data['user'] == "USLACKBOT" || data['username'] == 'slackbot'
        # message without text is probably an edit
        return if data['text'].nil?

        message = Message.new(data, self)
        @last_received_message = message

        self.class.befores.each { |c| instance_exec(message, &c) }

        if convo = find_conversation(message)
          convo.handle(message)
        else
          trigger(message.event, message)
        end

        self.class.afters.each { |c| instance_exec(message, &c) }
      else
        trigger(data['type'], data)
      end
    end

    def trigger(event, message)
      relevant_callbacks = self.class.callbacks_for(event)
      if relevant_callbacks && relevant_callbacks.any?
        relevant_callbacks.each do |c|
          resp = instance_exec(message, &c)
          break if resp == false
        end
      end
    end

    def find_conversation(message)
      @convos.detect do |convo|
        convo.active? &&
        convo.source_message.channel == message.channel &&
        convo.source_message.user == message.user
      end
    end

    def log(message)
      text = message.is_a?(String) ? message : message.inspect
      text = "[BOT/#{user}] #{text}"
      Rebot.logger.info(message)
    end

    def debug(message)
      text = message.is_a?(String) ? message : message.inspect
      text = "[BOT/#{user}] #{text}"
      Rebot.logger.debug(message)
    end

    def user
      auth_test['user']
    end

    def user_id
      auth_test['user_id']
    end

    def team
      auth_test['team']
    end

    def auth_test
      @auth_test ||= @api.auth_test
    end

    def load_im_channels
      debug "Loading IM channels"
      result = @api.im_list
      @im_channel_ids = result['ims'].map { |d| d['id'] }
      debug im_channels: @im_channel_ids
    end

    def load_channels
      debug "Loading Channels"
      result = @api.channels_list(exclude_archived: 1)
      @channel_ids = result['channels'].select { |d| d['is_member'] == true }.map { |d| d['id'] }
      debug channels: @channel_ids
    end
  end
end

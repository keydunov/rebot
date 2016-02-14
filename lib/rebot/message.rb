module Rebot
  class Message
    attr_reader :text, :user, :channel, :event

    def initialize(data, bot)
      @data    = data
      @bot     = bot

      @mention_regex = /\A(<@#{bot.bot_user_id}>)[\s\:](.*)/

      @user    = data['user']
      @channel = data['channel']
      @event   = resolve_event(data['type'])
      @text    = cleanup_text(data['text'])
    end

    def []=(key, value)
      @data[key.to_s] = value
    end

    def [](key)
      @data[key.to_s]
    end

    private

    def resolve_event(type)
      # set up a couple of special cases based on subtype
      if @data['event']
        @data['event']
      elsif @data['subtype'] == 'channel_join'
        if @data['user'] == @bot.bot_user_id
          "bot_channel_join"
        else
          "user_channel_join"
        end
      elsif @data['subtype'] == 'group_join'
        if @data['user'] == @bot.bot_user_id
          "bot_group_join"
        else
          "bot_group_join"
        end
      elsif @data['subtype']
        @data['subtype']

      elsif @data['channel'].match(/^D/)
        'dm'
      elsif @data['text'] =~ @mention_regex
        'mention'
      else
        "ambient"
      end
    end

    def cleanup_text(text)
      text = text.strip
      if md = text.match(@mention_regex)
        text = md[2].strip
      end
      text = text.gsub(/&lt;/, '<');
      text = text.gsub(/&gt;/, '>');
      text = text.gsub(/&amp;/, '&');
      text
    end
  end
end

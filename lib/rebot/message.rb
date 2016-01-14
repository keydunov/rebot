module Rebot
  class Message
    attr_reader :text, :user, :channel, :event

    def initialize(data, bot)
      @data    = data

      @mention_regex = /\A(<@#{bot.bot_user_id}>)[\s\:](.*)/

      @event   = resolve_event(data['type'])
      @text    = cleanup_text(data['text'])
      @user    = data['user']
      @channel = data['channel']
    end

    def []=(key, value)
      @data[key.to_s] = value
    end

    def [](key)
      @data[key.to_s]
    end

    private

    def resolve_event(type)
      if @data['text'] =~ @mention_regex
        type = 'mention'
      elsif @data['channel'].match(/^D/)
        type = 'dm'
      end
      type
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

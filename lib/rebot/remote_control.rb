module Rebot
  class RemoteControl
    def self.add_token(token)
      queue.push([:add_token, token])
    end

    def self.remove_bot(key)
      @queue.push([:remove_bot, key])
    end

    def self.say(key, message_data)
      queue.push([:say, key, message_data])
    end

    def self.call(key, method, args)
      queue.push([:call, [key, method, args]])
    end

    def self.queue
      @queue ||= RedisQueue.new
    end
  end
end

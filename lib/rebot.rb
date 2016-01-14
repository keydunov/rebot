require 'slack'
require 'logger'

require 'slack_bot_server'
require 'slack_bot_server/redis_queue'

require "rebot/version"
require "rebot/message"
require "rebot/bot"
require "rebot/conversation"


module Rebot
  def self.logger
    @logger ||= Logger.new(STDOUT)
  end

  def self.conversation(name, &block)
    @convos ||= {}
    @convos[name.to_sym] = block
  end

  def self.find_conversation(name)
    if convo = @convos[name.to_sym]
      convo
    else
      raise "Cannot find conversation: #{name}"
    end
  end
end

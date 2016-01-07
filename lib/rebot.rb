require 'slack'
require 'logger'

require "rebot/version"
require "rebot/message"
require "rebot/bot"
require "rebot/server"
require "rebot/conversation"
require "rebot/redis_queue"
require "rebot/remote_control"

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

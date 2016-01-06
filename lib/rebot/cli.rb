require "thor"

module Rebot
  class CLI < Thor
    include Thor::Actions
    class_option :verbose, type: :boolean, default: true, aliases: "-v"

    attr_reader :bot_name

    source_root File.expand_path("../../../template", __FILE__)

    desc "new [BOT_NAME]", "Creates a BOT_NAME dir with your new bot structure."
    def new(bot_name)
      @bot_name = bot_name
      directory "project", bot_name, verbose: verbose
      after_create
    end

    private

    def verbose
      options[:verbose]
    end

    def after_create
      inside @bot_name do
        run "chmod +x bot"
        run "bundle install"
      end
    end
  end
end

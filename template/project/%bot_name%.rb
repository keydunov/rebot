class <%= @bot_class %> < Rebot::Bot
  hears "who are you?" do
    reply "My name is `#{identity.name}` and I am here to help you, boss."
  end

  hears /^(hi|hello)/i do
    start_conversation :hello
  end

end

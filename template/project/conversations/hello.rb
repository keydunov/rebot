Rebot.conversation :hello do
  say "Hi!"
  say "How are you doing?"
  say "Do you have any plans for a weekend?"

  hears yes do
    say "Nice! :+1:. Hope you have a great weekend!"
  end

  hears no do
    say "Oh! Do you want to play with rebot framework"
    say "Check it out at https://github.com/keydunov/rebot"
  end
end

# Rebot

Rebot is a framework for building bots application.
Rebot was extracted from [brobot.io](http://brobot.io) and inspired by awesome node.js [botkit](https://github.com/howdyai/botkit) library. 

## Getting started

Create new app

    $ gem install rebot
    $ rebot new my_bot

Create new slack bot integration at [http://slack.com/services](http://slack.com/services) and copy token.

    $ cd my_bot
    $ TOKENS=token-your-copied-from-slack ./server

Text `hi` to your new bot.

## Usage

Rebot uses `conversations` to enable developers create complex text interactions.

```ruby
hears /^(hi|hello)/i do
  start_conversation do
    say "Hi!"
    say "How are you doing?"
    say "Do you have any plans for a weekend?"
    
    hears yes do
      say "Nice! Hope you have a great weekend!"
    end
    
    hears no do
      say "Oh! Do you want to play with `rebot` framework?"
      say "Check it out at https://github.com/keydunov/rebot"
    end
  end
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/rebot. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


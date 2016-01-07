# Rebot

Rebot is a framework for building bots application.

## Installation

    $ gem install rebot

## Usage

Create new app

    $ rebot new my_bot

Create new bot slack bot integration at (http://slack.com/services)[http://slack.com/services] and copy token.

    $ cd my_bot
    $ TOKENS=token-your-copied-from-slack ./server

Text `hi` to your new bot.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/rebot. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


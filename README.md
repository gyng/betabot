# UntitledBot - changeme

UntitledBot is a chatbot that aims to be protocol agnostic, easy to deploy and simple to develop for. UntitledBot supersedes [HidoiBot](https://github.com/gyng/HidoiBot).

Features network adapters and plugin framework goodies (database ORM, settings, packaging, install).

An IRC adapter is included. A web-based bouncer and public site in the roadmap.



## Installation

0. Requirements: Ruby version >= 2.0

1. Download or clone this repository.

        git clone https://github.com/gyng/WaruiBot.git

2. Install the gems with Bundler

        bundle install

3. Create an admin account (auth level 5)

        rake make_user

4. Configure the bot. Settings files that need changing:<br>
    * `./lib/settings/bot_settings.json`
    * `./lib/adapters/irc/settings/settings.json` (and any per-adapter settings)

5. Start the bot

        ruby start_bot.rb

## Usage

### Triggers (commands)
`BotNickname: command arg1 arg2` or `(trigger_shorthand)command arg1 arg2`

For example: `!ping`, `MyBot: ping`

#### Some commands

* login nick pass
* logout
* reload (reloads plugins)
* restart
* reconnect
* quit (closes the connection but does not stop the bot)
* shutdown
* useradd accountname password authlevel

### Installing plugins

To install a plugin from a URL:

1. Run `rake install_plugin[http://www.example.com/myplugin.af84ad46.package.zip]`.
2. Run `bundle install` to install plugin dependencies.
3. If there is a running bot instance, `reload` to reload all plugins.



## Plugin development

### Scaffold

There is a rake task to create a skeleton plugin. This uses the Ping plugin as a template.

    rake make_plugin[name]

The created plugin is located at `./lib/plugins/name/name.rb`.


### Dependencies

Include your gem dependencies in the plugin's Gemfile (as you would usually do for any application). This is *not* the same Gemfile located at the bot's root directory. The plugin's Gemfile will get picked up when a `bundle install` is run. See `./lib/plugins/ping/Gemfile` for an example.

### Gotchas

Do not block the [EventMachine](https://github.com/eventmachine/eventmachine) reactor! This means:

* No sleep(1)
* No long loops (100_000.times)
* No blocking I/O (slow SQL queries)
* No polling (while !condition)

Use EventMachine substitutes for these instead. EventMachine is used for non-blocking socket reads. If your event handler takes too long, other events cannot fire.

Possible solutions:

* `EM.add_timer(1) { stop_adapters; EM.stop }`
* `EM.add_periodic_timer(period) { ...do stuff... }`
* `Thread.new { ...do stuff... }

[A good overview of EventMachine](http://www.scribd.com/doc/28253878/EventMachine-scalable-non-blocking-i-o-in-ruby)

### Database

UntitledBot uses [Sequel](https://github.com/jeremyevans/sequel) ORM backed by SQLite. Plugins can either create their own databases or access a shared database.

The shared database can be accessed through the Bot's `attr_reader :shared_db` &ndash; `@bot.shared_db.run 'SELECT * FROM amazing;'`. Alternatively, create a database with `db = Bot::Database.new(path)`

[An excellent Sequel jumpstart tutorial](http://tutorials.jumpstartlab.com/topics/sequel.html)

### Listen to all messages

If the required plugin setting `@s[:subscribe]` is set to `true`, the plugin will receive all messages published by adapters via `#receive(message)`.

### Triggers

In the plugin settings hash `@s` the trigger key is required:

    trigger: { ping: [:call, 0] }

* `ping` is the trigger the bot responds to
* `:call` is the method in the plugin the bot calls when responding to
* `0` is the required authentication level of the user.

Multiple triggers are supported: `trigger: { ping: [:pong, 0], pong: [:peng, 0] }`

### Arguments

Arguments can be retrieved from the passed-in message

`BotName: hello world` or `!hello world`

... passed to ...

    # hello.rb

    m.args
    => ["hello", "world"]

### Fine authentication

If finer control over authentication is needed, Bot::Plugin offers a `#auth(level, message)` helper method.

    # plugin.rb

    ...

    def call(m)
      case m.args[1]
      when 'wakeup'
        m.reply 'Nope!'
        m.reply 'BOSS?' if auth(5, m)
      when 'sleep'
        ...
      end
    end

    ...

### Packaging plugins

Installable plugins can be packaged with `rake package_plugin[plugin_name]`.

The zip package will be located in the `./packages` folder. This package can be installed by running `rake install_plugin[http://myurl.com/plugin_name.sha31fda.plugin.zip]`. Do not change the filename as it is used in the install process.



## Tests

Tests can be run with `rspec`. Test coverage is nearly non-existent and contributions are welcome. It's painful to test since the EventMachine reactor has to be set up and torn down for adapters and core components.



## License
UntitledBot is licensed under the MIT License.
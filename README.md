# Hudda

Hudda is a chatbot that aims to be protocol agnostic, easy to deploy and simple to develop for. Hudda supersedes [HidoiBot](https://github.com/gyng/HidoiBot).

Features network adapters and plugin framework goodies (database ORM, settings, packaging, install).

An IRC adapter and some useful plugins are included. A web-based bouncer and public site in the roadmap.



## Installation

0. Requirements: Ruby version >= 2.0

1. Download or clone this repository.

        git clone https://github.com/gyng/WaruiBot.git

2. Install the gems with Bundler

        bundle install

3. Create an admin account (auth level 5) with the wizard

        rake make_user

4. Configure the bot. Settings files that need changing:<br>
    * `./lib/settings/bot_settings.json`
    * `./lib/adapters/irc/settings/settings.json` (and any per-adapter settings)
    * (Optional) any plugin settings.

5. Start the bot

        ruby start_bot.rb

## Usage

### Triggers (commands)
`BotNickname: command arg1 arg2` or `(trigger_shorthand)command arg1 arg2`

For example: `!ping`, `MyBot: ping`

#### Notable default plugins

* **chat** &ndash; Learning Markov chat. Run `!chat educate` on first run to feed it `./lib/plugins/chat/settings/textbook.txt`. Learns from user text.
* **image** &ndash; Saves all image links and records data about them in a database. Images are saved in `./public/i`.
* **entitle** &ndash; Echos titles of uninformative URLs.
* **entitleri** &ndash; Uses Google reverse image search to guess what image URLs are.
* **mpcsync** &ndash; Synchronizes playing of video files in MPC. Requires configuration of MPC addresses.
* **script/macro** &ndash; Script/Macro definition support.
* **translate** &ndash; Translates text with Bing translate. *requires setup of API keys*
* **wolfram** &ndash; Queries Wolfram|Alpha. *requires setup of API keys*

#### (Some) core commands

* help
* help plugin
* blacklist
* blacklist_adapter name
* blacklist_plugin name
* unblacklist_adapter name
* unblacklist_plugin name
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

If the bot is eating your exceptions, run it with `ruby start_bot.rb -dev`.

### Scaffold

There is a rake task to create a skeleton plugin. This uses the Ping plugin as a template.

    rake make_plugin[name]

The created plugin is located at `./lib/plugins/name/name.rb`.


### Dependencies

Include your gem dependencies in the plugin's Gemfile (as you would usually do for any application). This is *not* the same Gemfile located at the bot's root directory. The plugin's Gemfile will get picked up when a `bundle install` is run. See `./lib/plugins/ping/Gemfile` for an example.

### Gotchas

#### Settings

Setting files are persistent! Delete `yourplugin/settings/settings.json` if the settings hash `@s` has been modified and it will be regenerated from the defaults defined as `@s`. A handy raketask for this can be run with `rake default_plugin_settings[yourplugin]`.

#### EventMachine

Do not block the [EventMachine](https://github.com/eventmachine/eventmachine) reactor! This means:

* No sleep(1)
* No long loops (100_000.times)
* No blocking I/O (slow SQL queries)
* No polling (while !condition)

Use EventMachine substitutes for these instead. EventMachine is used for non-blocking socket reads. If your event handler takes too long, other events cannot fire.

Possible solutions:

* `EM.add_timer(1) { stop_adapters; EM.stop }`
* `EM.add_periodic_timer(period) { ...do stuff... }`
* `Thread.new { ...do stuff... }`

[A good overview of EventMachine](http://www.scribd.com/doc/28253878/EventMachine-scalable-non-blocking-i-o-in-ruby)

### Databases

Hudda uses [Sequel](https://github.com/jeremyevans/sequel) ORM backed by SQLite. Plugins can either create their own databases or access a shared database.

The shared database can be accessed through the Bot's `attr_reader :shared_db` &ndash; `@bot.shared_db.run 'SELECT * FROM amazing;'`. Alternatively, create a database with `db = Bot::Database.new(path)`

Check out the *image* plugin for an example of using a plugin-created database.

[An excellent Sequel jumpstart tutorial](http://tutorials.jumpstartlab.com/topics/sequel.html)

### Listen to all messages

If the required plugin setting `@s[:subscribe]` is set to `true`, the plugin will receive all messages published by adapters via `#receive(message)`.

### Triggers

In the plugin settings hash `@s` the trigger key is required:

    trigger: { ping: [:call, 0, 'help'] }

* `ping` is the trigger the bot responds to
* `:call` is the method in the plugin the bot calls when responding to
* `0` is the required authentication level of the user.
* `'help'` is the help string associated with this trigger. This is optional which means you can do `trigger: { ping: [:call, 0] }`

Multiple triggers are supported: `trigger: { ping: [:pong, 0], pong: [:peng, 0] }`

### Arguments

Arguments can be retrieved from the passed-in message

`BotName: hello world` or `!hello world`

... passed to ...

    # hello.rb

    message.args
    => ["hello", "world"]

### Messages

What a message contains can be defined by the adapter.

IRC's Message class has

* `adapter`
* `sender` nickname
* `real_name`
* `hostname`
* `type` eg. PONG, NOTICE, PRIVMSG
* `channel`
* `text` stripped of trigger prefixes
* `raw`
* `time`
* `origin`
* `args` message text split by spaces
* `mode` shorthand for `args[0]`

### Fine authentication

If finer control over authentication is needed, Bot::Plugin offers an `auth(level, message)` helper method.

    # plugin.rb

    ...

    def call(m)
      case m.args[0]
      when 'wakeup'
        m.reply 'Nope!'
        m.reply 'BOSS?' if auth(5, m)
      when 'sleep'
        ...
      end
    end

    ...

The method `auth_r(level, message)` replies to the message sender if authentication fails.

### Packaging plugins

Installable plugins can be packaged with `rake package_plugin[plugin_name]`.

The zip package will be located in the `./packages` folder. This package can be installed by running `rake install_plugin[http://myurl.com/plugin_name.sha31fda.plugin.zip]`. Do not change the filename as it is used in the install process.



## Tests

Tests can be run with `rspec`. More tests are being written; current test coverage is still very limited.

The EventMachine reactor has to be set up and torn down for most specs so there is a helper method `with_em(&block)` included in `spec_helper.rb`.



## License
Hudda is licensed under the MIT License.

# Plugin development

Please see [betabot-example-plugin](https://github.com/gyng/betabot-example-plugin) for a complete example of an external (ie. not bundled) plugin.

## Example plugin

```ruby
class Bot::Plugin::Ping < Bot::Plugin
  def initialize(bot)
    # Default settings: trigger: [method_symbol, auth_level, help_string]
    #                   subscribe: listen in to all messages?
    # Each trigger can call a different method.
    @s = {
      trigger: { ping: [:call, 0, 'Pings the bot.'] },
      subscribe: false
    }
    super(bot)
  end

  def call(m=nil)
    m.reply('pong')
  end

  # The method called if subscribe is true.
  def receive(m)
  end
end
```

## Dependencies

Include your gem dependencies in the plugin's Gemfile (as you would usually do for any application). This is *not* the same Gemfile located at the bot's root directory. The plugin's Gemfile will get picked up when a `bundle install` is run. See `./lib/plugins/ping/Gemfile` for an example.

## Tests

### External plugins

Include your tests inside a `spec` directory, in the plugin directory. See [betabot-example-plugin](https://github.com/gyng/betabot-example-plugin) for a concrete example.

```ruby
group :test do
  gem 'betabot', git: 'git@github.com:gyng/betabot.git'
  gem 'rspec'
end
```

### Bundled plugins

For bundled plugins, do the same. The specfiles will be picked up by `rspec`. See `Ping` for an example.

## Gotchas

### Settings

Setting files are persistent! Delete `lib/settings/<plugin_name>.json` if the settings hash `@s` has been modified and it will be regenerated from the defaults defined as `@s`.

### EventMachine

Do not block the [EventMachine](https://github.com/eventmachine/eventmachine) reactor! This means:

* No sleep(1)
* No long loops (100_000.times)
* No blocking operations (eg. slow SQL queries)
* No polling (while !condition)

Use EventMachine substitutes for these instead. EventMachine is used for non-blocking socket reads. If your event handler takes too long, other events cannot fire.

Possible solutions:

* `EM.add_timer(1) { stop_adapters; EM.stop }`
* `EM.add_periodic_timer(period) { ...do stuff... }`
* `Thread.new { ...do stuff... }`

[A good overview of EventMachine](http://www.scribd.com/doc/28253878/EventMachine-scalable-non-blocking-i-o-in-ruby)

## Databases

betabot uses [Sequel](https://github.com/jeremyevans/sequel) ORM backed by SQLite. Plugins can either create their own databases or access a shared database.

The shared database can be accessed through the Bot's `attr_reader :shared_db` &ndash; `@bot.shared_db.run 'SELECT * FROM my_table;'`. Alternatively, create a database with `Bot::Database.new(File.join(Bot::DATABASE_DIR, 'my_db.sqlite3'))`. Databases should be created inside the database directory so they can be persisted by Docker.

Check out the *image* plugin for an example of using a plugin-created database.

[An excellent Sequel jumpstart tutorial](http://tutorials.jumpstartlab.com/topics/sequel.html)

## Listen to all messages

If the required plugin setting `@s[:subscribe]` is set to `true`, the plugin will receive all messages published by adapters via `#receive(message)`.

## Triggers

In the plugin settings hash `@s` the trigger key is required:

    trigger: { ping: [:call, 0, 'help'] }

* `ping` is the trigger the bot responds to
* `:call` is the method in the plugin the bot calls when responding to
* `0` is the required authentication level of the user.
* `'help'` is the help string associated with this trigger. This is optional which means you can do `trigger: { ping: [:call, 0] }`

Multiple triggers are supported: `trigger: { ping: [:pong, 0], pong: [:peng, 0] }`

## Arguments

Arguments can be retrieved from the passed-in message

`BotName: hello world` or `!hello world`

... passed to ...

    # hello.rb

    message.args
    => ["hello", "world"]

## Messages

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

## Fine authentication

If finer control over authentication is needed, Bot::Plugin offers an `auth(level, message)` helper method.

```ruby
# plugin.rb

def call(m)
  case m.args[0]
  when 'wakeup'
    m.reply 'Nope!'
    m.reply 'Uh...' if auth(5, m)
  when 'sleep'
    sleep 1
  end
end

```

The method `auth_r(level, message)` replies to the message sender if authentication fails.

## Packaging plugins

Installable plugins should be an accessible git repository. Please see [betabot-example-plugin](https://github.com/gyng/betabot-example-plugin) for an example of an external (ie. not bundled) plugin.

## Web hook

betabot runs the Sinatra web microframework by default. To hook into this, do the following and make sure it gets called somehow, somewhen. You can put this in your plugin's `initialize`.

```ruby
if defined?(Web)
  Web.get '/mypath' do
    "Hello, world!"
  end
end
```

This will make available the route `http://yourconfiguredurl/mypath` (configured in `settings/bot_settings.user.json`) which just displays the string "Hello, world!".

You will probably need to access instance variables used by your plugin for your web route. Use a closure like this:

```ruby
random_proc = -> (n) {
  @db[:images].order(Sequel.lit('RANDOM()')).limit(n).to_a
}

if defined?(Web)
  Web.get '/i/random' do
    image = random_proc.call(1).first
    path = image[:path]
    redirect path
  end
end
```

Check out the Image plugin for a concrete example.

## Default plugin scaffold

There is a rake task to create a skeleton bundled plugin, but this is not intended for external developers. This uses the Ping plugin as a template.

    rake make_plugin[name]

The created plugin is located at `./lib/plugins/name/name.rb`.

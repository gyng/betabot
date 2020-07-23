# betabot

```irc
* betabot has joined #teatime
<gyng> ~ping
<betabot> pong
<gyng> betabot: remind me about tea in 10 seconds
<betabot> Reminder in 0.0h set for 1970-01-01 00:00:10 UTC (UTC).
<betabot> 🔔 -0.0h gyng > gyng: tea

<gyng> ~install https://plugin.example.com/my_plugin/manifest.json save
<betabot> 🎉 Plugin pong installed.
<gyng> ~pong
<betabot> peng
```

betabot is a bot that aims to be protocol agnostic, easy to deploy and simple to develop for.

Features network adapters and plugin framework goodies (database ORM, web hooks, settings, install).

Has full IRC and basic Slack and Discord support. Some useful plugins are also included. Not all included plugins support Slack and Discord right now.

## Installation

You can choose either to use or not to use Docker to run betabot.

0. Download or clone this repository

       git clone https://github.com/gyng/betabot.git

### First run

#### With Docker

[Docker Hub](https://hub.docker.com/r/gyng/betabot/)

0. Requirements: [Docker](https://www.docker.com/products/overview), [Docker Compose V2](https://docs.docker.com/compose/install/)

1. Use the image: `docker pull gyng/betabot`, or

2. Build the image from source. You might need to configure the ports used by the webserver and plugins.

       docker build . -t betabot

3. Create an admin account (auth level 5) with the wizard

       docker-compose run --entrypoint sh bot
       rake make_user

       # or with the command

       docker-compose run --entrypoint sh bot
       rake make_user_cmd[name,password,auth_level]

4. [Configure the bot](#configuration)

5. Start the bot

       docker-compose up

       # or in detached mode

       docker-compose up -d

6. Install external plugins if wanted

       # for example, as an admin
       ~login user pass
       ~install https://raw.githubusercontent.com/gyng/betabot-example-plugin/master/manifest.json

7. See commands

       # For plugins
       ~help

       # For core triggers (admin)
       ~help core

Settings, accounts, databases, and the public directory are persisted with usage of Docker. The image needs to be rebuilt (easily with `docker-compose up --build -d`) when adapters or plugins are changed or added. As of now, the port mappings in `docker-compose.yml` must be changed manually when not using default ports.

#### Without Docker

1. Requirements: [Ruby version >= 2.3](https://www.ruby-lang.org/en/downloads/), [Bundler](http://bundler.io/).

2. Install the gems with Bundler. You might need `sqlite-dev` and `imagemagick` packages installed on your system for gem installation.

       bundle install

3. Create an admin account (auth level 5) with the wizard

       rake make_user

   or the command

       rake make_user_cmd[name,password,auth_level]

4. [Configure the bot](#configuration)

5. Start the bot

       ruby start_bot.rb

## Usage

### Configuration

  For bot settings, betabot will read from `bot_settings.user.json`. This file will be automatically created on startup if it does not exist. `bot_settings.user.json` is ignored in `.gitignore`, which makes it easier to update betabot using git.

  ```
  cd lib/settings
  cp bot_settings.default.json bot_settings.user.json
  ```

  Settings files that may need changing:<br>
  * `./lib/settings/bot_settings.user.json` (for web server configuration options check below)
  * `./lib/settings/adapters/irc.json` (and any per-adapter settings)
  * `./lib/settings/adapters/slack.json` (and any per-adapter settings)
  * `./lib/settings/adapters/discord.json` (and any per-adapter settings)
  * (Optional) any plugin settings in `./lib/settings/plugins/`

  Add the adapters to be run on startup to the autostart key in `bot_settings.user.json`. Currently supported adapters are `slack` and `irc`.

  **Note that adapter and plugin settings files are generated with default settings on first run for a fresh install as of now. They do not exist before first run.**

#### Discord

If using Discord, you will need to invite your bot instance to your server. Use the [permissions generator](https://discordapi.com/permissions.html#515136) and insert your client ID.
An app can be created at the [Discord developer dashboard](https://discordapp.com/developers/applications/me). `api_token` refers to the app bot user's token.

#### Web server configuration details

* `enabled` &ndash; whether the webserver runs on startup
* `link_url` &ndash; the URL for plugins to use (eg. http://lollipop.hiphop:9999 or http://www.example.org)
* `host` &ndash; the listening host; leave this at `0.0.0.0` and it *should* work
* `port` &ndash; your listening port

#### Disable SSL verification

Run bot with `BETABOT_SSL_NO_VERIFY=1`.

```
BETABOT_SSL_NO_VERIFY=1 ruby start_bot.rb
```

#### (IRC) Calling the bot

`BotNickname: command arg1 arg2` or `(trigger_shorthand)command arg1 arg2`

For example: `!ping`, `MyBot: ping`

#### A few default plugins

* **image** &ndash; Saves all image links and records data about them in a database. Images are saved in `./public/i`. The image plugin also gives a random image link from the image database if the web server is running.
* **entitle** &ndash; Echos titles of uninformative URLs.
* **entitleri** &ndash; Uses Google reverse image search to guess the contents of image URLs.
* **shipment** &ndash; Tracks packages using Aftership *[requires setup of API keys](https://secure.aftership.com/#/settings/api)*
* **mpcsync** &ndash; Synchronizes playing of video files in MPC. Requires configuration of MPC addresses.
* **script/macro** &ndash; Script/Macro definition support.
* **showtime** &ndash; Checks Anilist for anime airing times *[requires setup of API keys](https://anilist.co/settings/developer)*
* **unicode** &ndash; Search for Unicode characters or emoji by description, and identify Unicode characters
* **wolfram** &ndash; Queries Wolfram|Alpha. *[requires setup of API keys](https://developer.wolframalpha.com/portal/apisignup.html)*

For all plugins, see the plugins and external_plugins directory.

#### Core commands

Use `~help core` for help with core commands.

* help
* help [plugin]
* help core
* install [external_plugin_manifest_json_url]
* install [external_plugin_manifest_json_url] save
* update [external_plugin_name]
* update [external_plugin_name] save
* remove [external_plugin_name]
* remove [external_plugin_name] save
* plugin_check_list
* reset_plugin [plugin_name]
* blacklist
* blacklist_adapter [name]
* blacklist_plugin [name]
* blacklist_user [name regex]
* blacklist_content [name regex]
* unblacklist_adapter [name]
* unblacklist_plugin [name]
* unblacklist_user [name regex]
* unblacklist_content [name regex]
* login [nick] [pass]
* logout
* reload  # (reloads plugins)
* restart
* reconnect
* disconnect
* shutdown
* useradd [accountname] [password] [authlevel 0-5]
* version

### Plugin management

#### As a command (Recommended)

As an admin account (auth >= 5):

```
~install <manifest_url>
~install <manifest_url> save
~update <plugin_name>
~remove <plugin_name>
~remove <plugin_name> save
~plugin_check_list
```

If `save` is supplied, the plugin will be added to the list of plugins to be checked for installation/updates on startup. These settings are saved to `bot_settings.user.json`.

The plugin might require dependencies. If so, run `bundle install` and restart the bot.

#### CLI (Not recommended)

```
rake install_plugin[$MANIFEST_URL]
rake update_plugin[$PLUGIN_NAME]
rake remove_plugin[$PLUGIN_NAME]
```

These commands do not provide options to update `bot_settings.user.json` and are therefore not recommended.

### Plugin development

See: [Plugin development](PLUGINS.md)

## Tests

Docker: `docker-compose -f docker-compose.test.yml up --build

Tests can be run with `bundle exec rspec`. Current test coverage is very limited. Ruocop can be run with `bundle exec rubocop`.

The EventMachine reactor has to be set up and torn down for most specs so there is a helper method `with_em(&block)` included in `spec_helper.rb`.

Tests for plugins are to be placed inside a `spec` directory in the plugin directory. See the ping plugin for an example.

The project is linted with Rubocop, and will fail CI if any violations are found.

## License
betabot is licensed under the MIT License.

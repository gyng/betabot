# betabot
[![Build Status](https://travis-ci.org/gyng/betabot.svg?branch=Travis)](https://travis-ci.org/gyng/betabot)

```irc
* betabot has joined #teatime
<gyng> ~ping
<betabot> pong
<gyng> betabot: remind me about tea in 10 seconds
<betabot> Reminder in 0.0h set for 1970-01-01 00:00:10 UTC (UTC).
<betabot> 🔔 -0.0h gyng > gyng: tea
```

betabot is a bot that aims to be protocol agnostic, easy to deploy and simple to develop for.

Features network adapters and plugin framework goodies (database ORM, web hooks, settings, packaging, install).

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

Settings, accounts, databases, and the public directory are persisted with usage of Docker. The image needs to be rebuilt (easily with `docker-compose up --build -d`) when adapters or plugins are changed or added. As of now, the port mappings in `docker-compose.yml` must be changed manually when not using default ports.

#### Without Docker

1. Requirements: [Ruby version >= 2.2.2](https://www.ruby-lang.org/en/downloads/), [Bundler](http://bundler.io/).

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

  For bot settings, betabot will read from `bot_settings.user.json` instead of `bot_settings.json` if it exists. `bot_settings.user.json` is ignored in `.gitignore`, which makes it easier to update betabot using git.

  ```
  cd lib/settings
  cp bot_settings.json bot_settings.user.json
  ```

  Settings files that may need changing:<br>
  * `./lib/settings/bot_settings.json` (for web server configuration options check below)
  * `./lib/settings/adapters/irc.json` (and any per-adapter settings)
  * `./lib/settings/adapters/slack.json` (and any per-adapter settings)
  * `./lib/settings/adapters/discord.json` (and any per-adapter settings)
  * (Optional) any plugin settings in `./lib/settings/plugins/`

  Add the adapters to be run on startup to the autostart key in `bot_settings.json`. Currently supported adapters are `slack` and `irc`.

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

For all plugins, see the plugin directory.

#### A few core commands

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

### Plugin development

See: [Plugin development](PLUGINS.md)

## Tests

Tests can be run with `rspec`. Current test coverage is very limited.

The EventMachine reactor has to be set up and torn down for most specs so there is a helper method `with_em(&block)` included in `spec_helper.rb`.

Tests for plugins are to be placed inside a `spec` directory in the plugin directory. See the ping plugin for an example.

The project is linted with Rubocop, and will fail CI if any violations are found.

## License
betabot is licensed under the MIT License.

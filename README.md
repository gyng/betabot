# betabot
[![Build Status](https://travis-ci.org/gyng/betabot.svg?branch=Travis)](https://travis-ci.org/gyng/betabot)

betabot is a bot that aims to be protocol agnostic, easy to deploy and simple to develop for.

Features network adapters and plugin framework goodies (database ORM, web hooks, settings, packaging, install).

An IRC adapter and some useful plugins are included.

## Installation

You can choose either to use or not to use Docker to run betabot.

0. Download or clone this repository

        git clone https://github.com/gyng/betabot.git

### First run

#### With Docker

1. Requirements: [Docker](https://www.docker.com/products/overview), [Docker Compose V2](https://docs.docker.com/compose/install/)

2. Build the image. You might need to configure the ports used by the webserver and plugins.

        docker build . -t betabot:latest

    or with port configuration:

        docker build . -t betabot:latest --build-arg PORT_WEB=80 --build-arg PORT_SYNC_LISTENER=15555

3. Create an admin account (auth level 5) with the wizard

        docker run -it --entrypoint=sh betabot:latest
        rake make_user

   or the command

        docker run -it --entrypoint=sh betabot:latest
        rake make_user_cmd[name,password,auth_level]

4. [Configure the bot](#configuration)

5. Start the bot

        docker-compose up

    or in detached mode

        docker-compose up -d

Settings, accounts, databases, and the public directory are persisted with usage of Docker. The image needs to be rebuilt (easily with `docker-compose up --build -d`) when adapters or plugins are changed or added.

#### Without Docker

1. Requirements: [Ruby version >= 2.0](https://www.ruby-lang.org/en/downloads/), [Bundler](http://bundler.io/).

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

  Settings files that need changing:<br>
  * `./lib/settings/bot_settings.json` (for web server configuration options check below)
  * `./lib/settings/adapters/irc.json` (and any per-adapter settings)
  * (Optional) any plugin settings in `./lib/settings/plugins/`

  Note that the plugin settings files are generated with default settings on first run for a fresh install. They do not exist before first run.

#### Web server configuration details
* `enabled` &ndash; whether the webserver runs on startup
* `link_url` &ndash; the URL for plugins to use (eg. http://lollipop.hiphop:9999 or http://www.example.org)
* `host` &ndash; the listening host; leave this at 0.0.0.0 and it *should* work
* `port` &ndash; your listening port


#### (IRC) Calling the bot
`BotNickname: command arg1 arg2` or `(trigger_shorthand)command arg1 arg2`

For example: `!ping`, `MyBot: ping`

#### A few default plugins

* **image** &ndash; Saves all image links and records data about them in a database. Images are saved in `./public/i`. The image plugin also gives a random image link from the image database if the web server is running.
* **entitle** &ndash; Echos titles of uninformative URLs.
* **entitleri** &ndash; Uses Google reverse image search and Microsoft Computer Vision API to guess what image URLs are. *Usage of MS CV API requires the setup of [>=free subscriptions](https://www.microsoft.com/cognitive-services/en-US/subscriptions)*
* **mpcsync** &ndash; Synchronizes playing of video files in MPC. Requires configuration of MPC addresses.
* **script/macro** &ndash; Script/Macro definition support.
* **translate** &ndash; Translates text with Bing translate. *[requires setup of API keys](https://datamarket.azure.com/dataset/bing/microsofttranslator)*
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

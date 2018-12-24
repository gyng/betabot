require 'spec_helper'
require 'eventmachine'
require 'bot/core'
require 'fixtures/bot'

describe Bot::Core do
  include Fixtures::Bot

  before(:each) do
    # Remove prior module constant definintion for each Bot::Core init to kill warnings
    [:ROOT_DIR, :SETTINGS_DIR, :DATABASE_DIR, :SHORT_TRIGGER].each do |const|
      Bot.send(:remove_const, const) if Bot.const_defined?(const)
    end
  end

  context 'Objects' do
    context 'Adapters' do
      it 'loads an adapter' do
        with_em do
          bot = Bot::Core.new(settings_filename_fixture)
          bot.load_adapter(:dummy)
          expect(bot.adapters).to have_key(:dummy)
        end
      end
    end

    context 'Plugins' do
      it 'loads a plugin' do
        with_em do
          bot = Bot::Core.new(settings_filename_fixture)
          bot.load_plugin(:dummy)
          expect(bot.plugins).to have_key(:dummy)
        end
      end
    end
  end

  context 'Settings' do
    it 'loads settings' do
      with_em do
        bot = Bot::Core.new(settings_filename_fixture)
        expect(bot.s).to eq settings_fixture
      end
    end
  end

  context 'Blacklist' do
    before do
      @bot = Bot::Core.new(settings_filename_blacklist_fixture)
      adapter = Bot::Adapter::Irc.new(true)
      handler = Bot::Adapter::Irc::Handler.new(adapter, {})

      blacklisted_user = ':nick!blacklisted_user@test.com PRIVMSG #test :test'
      @blacklisted_user_msg = handler.parse_data(blacklisted_user)
      ok_user = ':nick!ok_user@test.com PRIVMSG #test :test'
      @ok_user_msg = handler.parse_data(ok_user)

      @blacklisted_content_msg = handler.parse_data(ok_user)
      @blacklisted_content_msg.text = 'blacklisted_content'
      @ok_content_msg = handler.parse_data(ok_user)
      @ok_content_msg.text = 'ok_content'
    end

    it 'does not load adapters in blacklist' do
      expect(@bot.adapters).to have_key(:dummy)
      expect(@bot.adapters).to_not have_key(:irc)
    end

    it 'does not load plugins in blacklist' do
      bot = Bot::Core.new(settings_filename_whitelist_fixture)
      expect(bot.plugins).to have_key(:ping)
      expect(bot.plugins).to_not have_key(:dummy)
    end

    it 'checks against blacklist for a given type' do
      expect(@bot.blacklisted?(:user, 'blacklisted_user')).to be true
      expect(@bot.blacklisted?(:user, 'safe user')).to be false
    end

    it 'does not trigger plugins for messages from blacklisted users' do
      expect(@bot.trigger_plugin('not_a_core_trigger', @blacklisted_user_msg)).to be :blacklist
      expect(@bot.trigger_plugin('not_a_core_trigger', @ok_user_msg)).to_not be :blacklist
    end

    it 'does not publish for messages from blacklisted users' do
      expect(@bot.publish(@blacklisted_user_msg)).to be :blacklist
      expect(@bot.publish(@ok_user_msg)).to_not be :blacklist
    end

    it 'does not trigger plugins for messages with blacklisted content' do
      expect(@bot.trigger_plugin('not_a_core_trigger', @blacklisted_content_msg)).to be :blacklist
      expect(@bot.trigger_plugin('not_a_core_trigger', @ok_content_msg)).to_not be :blacklist
    end

    it 'does not publish for messages from blacklisted users' do
      expect(@bot.publish(@blacklisted_content_msg)).to be :blacklist
      expect(@bot.publish(@ok_content_msg)).to_not be :blacklist
    end
  end

  context 'Reload' do
    it 'reloads plugins' do
      with_em do
        bot = Bot::Core.new(settings_filename_blacklist_fixture)
        expect(bot.plugins).to_not have_key(:ping)

        # Load new additions
        bot.instance_variable_set(:@settings_path, settings_filename_whitelist_fixture)
        bot.reload(:plugin)
        expect(bot.plugins).to have_key(:ping)

        # Unload subtractions
        bot.instance_variable_set(:@settings_path, settings_filename_blacklist_fixture)
        bot.reload(:plugin)
        expect(bot.plugins).to_not have_key(:ping)
      end
    end

    # pending 'reloads adapters' do end
  end
end

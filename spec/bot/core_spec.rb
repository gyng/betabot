require 'spec_helper'
require 'eventmachine'
require 'bot/core'
require 'fixtures/bot'

describe Bot::Core do
  include Fixtures::Bot

  before(:each) do
    # Remove prior module constant definintion for each Bot::Core init
    # Else it throws warnings all over the place
    [:ROOT_DIR, :SETTINGS_DIR, :DATABASE_DIR, :SHORT_TRIGGER].each do |const|
      Bot.send(:remove_const, const) if Bot.const_defined?(const)
    end
  end

  context 'Objects' do
    context 'Adapters' do
      it 'loads an adapter' do
        EM.run do
          bot = Bot::Core.new(settings_filename_fixture)
          bot.load_adapter(:dummy)
          expect(bot.adapters).to have_key(:dummy)
          EM.stop
        end
      end

      it 'skips bad adapters' do
        EM.run do
          bot = Bot::Core.new(settings_filename_fixture)
          expect { bot.load_adapter(:nothing) }.to raise_error
          expect(bot.adapters).to_not have_key(:nothing)
          EM.stop
        end
      end
    end

    context 'Plugins' do
      it 'loads a plugin' do
        EM.run do
          bot = Bot::Core.new(settings_filename_fixture)
          bot.load_plugin(:dummy)
          expect(bot.plugins).to have_key(:dummy)
          EM.stop
        end
      end

      it 'skips bad plugins' do
        EM.run do
          bot = Bot::Core.new(settings_filename_fixture)
          expect { bot.load_plugin(:nothing) }.to raise_error
          expect(bot.adapters).to_not have_key(:nothing)
          EM.stop
        end
      end
    end
  end

  context 'Settings' do
    it 'loads settings' do
      EM.run do
        bot = Bot::Core.new(settings_filename_fixture)
        expect(bot.s).to eq settings_fixture
        EM.stop
      end
    end

    it 'does not load adapters in blacklist' do
      EM.run do
        bot = Bot::Core.new(settings_filename_blacklist_fixture)
        expect(bot.adapters).to have_key(:dummy)
        expect(bot.adapters).to_not have_key(:irc)
        EM.stop
      end
    end

    it 'does not load plugins in blacklist' do
      EM.run do
        bot = Bot::Core.new(settings_filename_whitelist_fixture)
        expect(bot.plugins).to have_key(:ping)
        expect(bot.plugins).to_not have_key(:dummy)
        EM.stop
      end
    end
  end

  context 'Reload' do
    it 'reloads plugins' do
      EM.run do
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

        EM.stop
      end
    end

    # pending 'reloads adapters' do end
  end
end
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
        with_em {
          bot = Bot::Core.new(settings_filename_fixture)
          bot.load_adapter(:dummy)
          expect(bot.adapters).to have_key(:dummy)
        }
      end

      it 'skips bad adapters' do
        with_em {
          bot = Bot::Core.new(settings_filename_fixture)
          expect { bot.load_adapter(:nothing) }.to raise_error
          expect(bot.adapters).to_not have_key(:nothing)
        }
      end
    end

    context 'Plugins' do
      it 'loads a plugin' do
        with_em {
          bot = Bot::Core.new(settings_filename_fixture)
          bot.load_plugin(:dummy)
          expect(bot.plugins).to have_key(:dummy)
        }
      end

      it 'skips bad plugins' do
        with_em {
          bot = Bot::Core.new(settings_filename_fixture)
          expect { bot.load_plugin(:nothing) }.to raise_error
          expect(bot.adapters).to_not have_key(:nothing)
        }
      end
    end
  end

  context 'Settings' do
    it 'loads settings' do
      with_em {
        bot = Bot::Core.new(settings_filename_fixture)
        expect(bot.s).to eq settings_fixture
      }
    end

    it 'does not load adapters in blacklist' do
      with_em {
        bot = Bot::Core.new(settings_filename_blacklist_fixture)
        expect(bot.adapters).to have_key(:dummy)
        expect(bot.adapters).to_not have_key(:irc)
      }
    end

    it 'does not load plugins in blacklist' do
      with_em {
        bot = Bot::Core.new(settings_filename_whitelist_fixture)
        expect(bot.plugins).to have_key(:ping)
        expect(bot.plugins).to_not have_key(:dummy)
      }
    end
  end

  context 'Reload' do
    it 'reloads plugins' do
      with_em {
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
      }
    end

    # pending 'reloads adapters' do end
  end
end
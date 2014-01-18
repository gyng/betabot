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

    pending 'does not load adapters in blacklist' do
    end

    pending 'does not load plugins in blacklist' do
    end
  end

  context 'Reload' do
    pending 'reloads plugins' do
      bot = Bot::Core.new(settings_filename_fixture)
      plugins = bot.plugins
      bot.s = settings_fixture
      bot.reload
      expect(bot.plugins.length).to be eq plugins.length + 1
    end

    pending 'reloads adapters' do
    end
  end
end
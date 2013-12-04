require 'spec_helper'
require 'bot/core'
require 'fixtures/bot'

describe Bot::Core do
  include Fixtures::Bot

  context 'Adapters' do
    before(:all) do
      @bot = Bot::Core.new(settings_fixture)
    end

    it 'loads an adapter' do
      @bot.load_adapter(:dummy)
      expect(@bot.adapters).to have_key(:dummy)
    end

    it 'skips bad adapters' do
      expect { @bot.load_adapter(:nothing) }.to raise_error
      expect(@bot.adapters).to_not have_key(:nothing)
    end
  end

  context 'Plugins' do
    before(:all) do
      @bot = Bot::Core.new(settings_fixture)
    end

    it 'loads a plugin' do
      @bot.load_plugin(:dummy)
      expect(@bot.plugins).to include :dummy
    end

    it 'skips bad plugins' do
      expect { @bot.load_plugin(:nothing) }.to raise_error
      expect(@bot.adapters).to_not have_key(:nothing)
    end
  end

  context 'Settings' do
    before do
      @bot = Bot::Core.new(settings_fixture)
    end

    it 'loads settings' do
      expect(@bot.settings.to_json).to eq settings_fixture
    end

    it 'connects to enabled adapters' do
      expect(@bot.active_adapters[0].class).to eq Bot::Adapter::Dummy
    end

    pending 'does not load adapters in blacklist' do
    end

    pending 'does not load plugins in blacklist' do
    end
  end

  context 'Reload' do
    it 'reloads plugins' do
      bot = Bot::Core.new(settings_fixture)
      plugins = bot.plugins
      bot.settings = extra_plugin_settings_fixture
      bot.reload
      expect(bot.plugins.length).to be eq plugins.length + 1
    end

    # pending 'reloads adapters' do
    # end
  end

  # context 'Shutdown' do
  # end
end
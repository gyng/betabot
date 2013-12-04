require 'spec_helper'
require 'bot/core'
require 'fixtures/bot'

describe Bot::Core do
  include Fixtures::Bot

  context 'Adapters' do
    before(:all) do
      @bot = Bot::Core.new
    end

    it 'loads an adapter' do
      @bot.load_adapter(:irc)
      expect(@bot.adapters).to eql [:irc]
    end

    it 'skips bad adapters' do
      @bot.load_adapter(:nothing)
      expect(@bot.adapters.empty?).to be_true
    end
  end

  context 'Plugins' do
    before(:all) do
      @bot = Bot::Core.new
    end

    it 'loads a plugin' do
      @bot.load_plugin(:ping)
      expect(@bot.plugins).to include :ping
    end

    it 'skips bad plugins' do
      @bot.load_plugin(:nothing)
      expect(@bot.plugins.empty?).to be_true
    end
  end

  context 'Settings' do
    before do
      @bot = Bot::Core.new(settings_fixture)
    end

    it 'loads adapters' do
      expect(@bot.adapters).to include :irc
    end

    it 'skips bad adapters' do
      expect(@bot.adapters).not_to include :dummy
    end

    it 'loads plugins' do
      expect(@bot.plugins).to include [:ping, :dummy]
    end

    it 'loads settings' do
      expect(@bot.settings.to_json).to eq settings_fixture
    end

    it 'connects to enabled adapters' do
      expect(@bot.active_adapters[0].class).to eq Bot::Adapter::Dummy
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
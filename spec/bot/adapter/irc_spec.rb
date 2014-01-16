require 'spec_helper'
require 'bot/core'
require 'bot/adapter'
require 'adapters/irc/irc'
require 'adapters/irc/handler'
require 'adapters/irc/message'

describe Bot::Adapter::Irc::Handler do
  before do
    Bot::ROOT_DIR = '.'
    @adapter = Bot::Adapter::Irc.new(true)
    @handler = Bot::Adapter::Irc::Handler.new(@adapter, {})
  end

  it 'parses PRIVMSG' do
    data = ':nick!real@test.com PRIVMSG #test :test'
    m = @handler.parse_data(data)
    expect(m.sender).to eq('nick')
    expect(m.real_name).to eq('real')
    expect(m.hostname).to eq('test.com')
    expect(m.type).to eq(:privmsg)
    expect(m.channel).to eq('#test')
    expect(m.text).to eq('test')
  end
end
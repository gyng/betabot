require 'spec_helper'
require 'bot/core'
require 'bot/adapter'
require 'adapters/irc/irc'
require 'adapters/irc/handler'
require 'adapters/irc/message'

describe Bot::Adapter::Irc::Handler do
  before do
    @irc = Bot::Adapter::Irc::Handler.new true
  end

  it 'parses PRIVMSG' do
    data = ':nick!real@test.com PRIVMSG #test :test'
    m = @irc.parse_data(data)
    expect(m.sender).to eq('nick')
    expect(m.real_name).to eq('real')
    expect(m.hostname).to eq('test.com')
    expect(m.type).to eq(:privmsg)
    expect(m.channel).to eq('#test')
    expect(m.text).to eq('test')
  end

  it 'registers with the server when connected' do
    Bot::Adapter::Irc::Handler.stub(:send_data).and_return(true)
    @irc.connection_completed
    Bot::Adapter::Irc::Handler.any_instance.should_receive(:register)
  end
end
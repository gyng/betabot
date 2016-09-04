require 'spec_helper'
require 'bot/core'
require 'bot/adapter'
require 'adapters/irc/irc'
require 'adapters/irc/handler'
require 'adapters/irc/message'

describe Bot::Adapter::Irc::Handler do
  before do
    Bot.send(:remove_const, :ROOT_DIR) if Bot.const_defined?(:ROOT_DIR)
    Bot.const_set(:ROOT_DIR, File.join(Dir.pwd, 'lib'))
    @adapter = Bot::Adapter::Irc.new(true)
    @handler = Bot::Adapter::Irc::Handler.new(@adapter, {})
  end

  context 'basic parsing' do
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

    it 'parses PING' do
      data = 'PING sender.hostname'
      m = @handler.parse_data(data)
      expect(m.type).to eq(:ping)
      expect(m.sender).to eq('sender.hostname')
    end
  end

  context 'on socket close' do
    # No idea how to cancel timers: can 'hack' by setting timer length
    # but that doesn't fix the problem. Ideally we should intercept
    # the timer call OR cancel all timers manually. This is blocking
    # rspec execution causing rspec to not finish.

    # it 'should reconnect if socket is unexpectedly closed' do
    #   with_em {
    #     @handler.instance_variable_set(:@state, :connected)
    #     @handler.unbind
    #     expect(@handler.state).to eq(:reconnecting)

    #     @handler.instance_variable_set(:@state, :waiting)
    #     @handler.unbind
    #     expect(@handler.state).to eq(:reconnecting)
    #   }
    # end

    it 'should not reconnect if socket is intentionally closed' do
      with_em do
        @handler.instance_variable_set(:@state, :connected)
        $shutdown = true
        @handler.unbind
        expect(@handler.state).to eq(:disconnected)

        @handler.instance_variable_set(:@state, :quitting)
        $shutdown = true
        @handler.unbind
        expect(@handler.state).to eq(:disconnected)
      end
    end
  end
end

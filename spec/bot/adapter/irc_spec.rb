require 'spec_helper'
require 'bot/core'
require 'bot/adapter'
require 'adapters/irc/irc'
require 'adapters/irc/handler'
require 'adapters/irc/message'

describe Bot::Adapter::Irc::Message do
  # rubocop:disable Layout/LineLength

  before do
    [:ROOT_DIR, :SETTINGS_DIR].each do |c|
      Bot.send(:remove_const, c) if Bot.const_defined?(c)
    end
    Bot.const_set(:ROOT_DIR, File.join(Dir.pwd, 'lib'))
    Bot.const_set(:SETTINGS_DIR, File.join(Dir.pwd, 'lib', 'settings'))
    @adapter = Bot::Adapter::Irc.new(true)
    @handler = Bot::Adapter::Irc::Handler.new(@adapter, {})
  end

  context 'text chunking' do
    it 'chunks long text at grapheme boundaries' do
      input = '【三浦建太郎先生　ご逝去の報】 ↵ 『ベルセルク』の作者である三浦建太郎先生が、2021年5月6日、急性大動脈解離のため、ご逝去されました。三浦先生の画業に最大の敬意と感謝を表しますとともに、心よりご冥福をお祈りいたします。 ↵ 2021年5月20日　株式会社白泉社　ヤングアニマル編集部 pic.twitter.com/baBBo4J2kL — ベルセルク公'
      m = Bot::Adapter::Irc::Message.new
      chunks = m.chunk(input, 350, 400).to_a
      expect(chunks.length).to eq(2)
      # Note trailing whitespace: rstrip doesn't handle unicode blanks
      expect(chunks[0]).to eq('【三浦建太郎先生　ご逝去の報】 ↵ 『ベルセルク』の作者である三浦建太郎先生が、2021年5月6日、急性大動脈解離のため、ご逝去されました。三浦先生の画業に最大の敬意と感謝を表しますとともに、心よりご冥福をお祈りいたします。 ↵ 2021年5月20日　')
      expect(chunks[1]).to eq('株式会社白泉社　ヤングアニマル編集部 pic.twitter.com/baBBo4J2kL — ベルセルク公')
    end

    it 'chunks long text at blank boundaries' do
      input = 'the quick brown fox jumps over the lazy dog'
      m = Bot::Adapter::Irc::Message.new
      chunks = m.chunk(input, 25, 30).to_a
      expect(chunks.length).to eq(2)
      expect(chunks[0]).to eq('the quick brown fox')
      expect(chunks[1]).to eq('jumps over the lazy dog')
    end
  end

  context 'message chunjking' do
    it 'replys with long text broken across multiple PRIVMSGs' do
      origin = double('origin')
      expect(origin).to receive(:send) do |x|
        expect(x).to eq('PRIVMSG channel :Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit…')
      end

      expect(origin).to receive(:send) do |x|
        expect(x).to eq('PRIVMSG channel :anim id est laborum.')
      end

      input = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.'
      msg = Bot::Adapter::Irc::Message.new do |m|
        m.origin = origin
        m.channel = 'channel'
      end

      msg.reply(input)
    end
  end

  # rubocop:enable Layout/LineLength
end

describe Bot::Adapter::Irc::Handler do
  before do
    [:ROOT_DIR, :SETTINGS_DIR].each do |c|
      Bot.send(:remove_const, c) if Bot.const_defined?(c)
    end
    Bot.const_set(:ROOT_DIR, File.join(Dir.pwd, 'lib'))
    Bot.const_set(:SETTINGS_DIR, File.join(Dir.pwd, 'lib', 'settings'))
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

  context 'addressing' do
    it 'parses an address' do
      adapter = Bot::Adapter::Irc.new(true)
      handler = Bot::Adapter::Irc::Handler.new(@adapter, {})
      adapter.instance_variable_set(:@connections, { foo: handler })
      msg = adapter.prepare_message('foo.#baz')
      expect(msg.channel).to eq('#baz')
      expect(msg.origin).to be(handler)
    end

    it 'handles bad addresses' do
      adapter = Bot::Adapter::Irc.new(true)
      handler = Bot::Adapter::Irc::Handler.new(@adapter, {})
      adapter.instance_variable_set(:@connections, { foo: handler })
      msg = adapter.prepare_message('badbad')
      expect(msg).to be_nil
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

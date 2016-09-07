require 'spec_helper'
require_relative '../tell.rb'

describe Bot::Plugin::Tell do
  before(:each) do
    @plugin = Bot::Plugin::Tell.new(nil)
  end

  it 'saves tells' do
    message_from_alice = Bot::Core::Message.new do |m|
      m.sender = 'Alice'
      m.text = 'tell Bob forget about Eve'
    end

    message_from_eve = Bot::Core::Message.new do |m|
      m.sender = 'Eve'
      m.text = 'tell Bob forget about Alice'
    end

    @plugin.tell(message_from_alice)
    @plugin.tell(message_from_alice)
    @plugin.tell(message_from_eve)

    stored_messages = @plugin.instance_variable_get(:@stored_messages)
    expect(stored_messages['Bob'][0][:message]).to eql('forget about Eve')
    expect(stored_messages['Bob'][0][:from]).to eql('Alice')
    expect(stored_messages['Bob'][0]).to eql(stored_messages['Bob'][1])
    expect(stored_messages['Bob'][2][:message]).to eql('forget about Alice')
    expect(stored_messages['Bob'][2][:from]).to eql('Eve')
  end

  it 'tells victims off' do
    now = Time.now.to_i

    tells = {
      'Bob' => [
        { from: 'Miho', at: now, message: 'foo' },
        { from: 'Maho', at: now, message: 'bar' }
      ],
      'Charles' => [
        { from: 'Mika', at: now, message: 'baz' }
      ]
    }

    @plugin.instance_variable_set(:@stored_messages, tells)

    message_from_bob = Bot::Adapter::Irc::Message.new do |m|
      m.sender = 'Bob'
      m.type = :join
    end

    expect(message_from_bob).to receive(:reply).exactly(2).times
    @plugin.receive(message_from_bob)

    expect(@plugin.instance_variable_get(:@stored_messages)).to eql('Charles' => tells['Charles'])
  end
end

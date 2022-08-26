require 'spec_helper'
require_relative '../ping'

describe Bot::Plugin::Ping do
  subject { Bot::Plugin::Ping.new(nil) }

  it 'responds to ping with pong' do
    m = Bot::Core::Message.new
    expect(m).to receive(:reply).with('pong')
    subject.method_to_call(m)
  end
end

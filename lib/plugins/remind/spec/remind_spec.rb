require 'spec_helper'
require_relative '../remind'

describe Bot::Plugin::Remind do
  before(:each) do
    @plugin = Bot::Plugin::Remind.new(nil)

    @message = Bot::Core::Message.new do |m|
      m.sender = 'Eve'
    end
  end

  describe 'timezone' do
    it '#country_tzs' do
      @message.text = 'tz country sg'
      c = @plugin.country_tzs(@message)
      expect(c).to eql('Asia/Singapore')
    end

    it '#find_zone exact match' do
      exact = @plugin.find_zone('us/pacific')
      expect(exact.length).to eql(1)
      expect(exact[0].name).to eql('US/Pacific')

      multiple = @plugin.find_zone('pacific')
      expect(multiple.length).to be > 1
    end
  end

  describe 'remind' do
    subject { Bot::Plugin::Remind.new(nil) }

    it 'sets a reminder with relative time' do
      with_em do
        m = Bot::Core::Message.new do |mm|
          mm.text = 'remind me about bananas in 10 minutes'
        end
        expect(m).to receive(:reply).with(a_string_including("Reminder in \e[31m\e[1m10m\e[22m\e[0m set for"))
        subject.remind(m)
      end
    end

    it 'sets a reminder with absolute time using a 2-letter country code' do
      with_em do
        m = Bot::Core::Message.new do |mm|
          mm.text = 'remind me about bananas at Sunday 10am sg'
        end
        expect(m).to receive(:reply).with(a_string_including('10:00:00 UTC (Asia/Singapore)'))
        subject.remind(m)
      end
    end

    it 'sets a reminder with absolute time using a tzinfo partial match' do
      with_em do
        m = Bot::Core::Message.new do |mm|
          mm.text = 'remind me about bananas at Sunday 10am edmonton'
        end
        expect(m).to receive(:reply).with(a_string_including('UTC (America/Edmonton)'))
        subject.remind(m)
      end
    end
  end

  describe 'timer' do
    subject { Bot::Plugin::Remind.new(nil) }

    it 'sets a timer for x minutes' do
      with_em do
        m = Bot::Core::Message.new do |mm|
          mm.text = 'timer 3 minutes'
        end
        expect(m).to receive(:reply).with(a_string_including("Timer in \e[31m\e[1m3m\e[22m\e[0m set for"))
        subject.timer(m)
      end
    end
  end
end

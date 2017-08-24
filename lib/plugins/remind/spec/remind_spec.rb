require 'spec_helper'
require_relative '../remind.rb'

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
      # @message.text = 'tz info us'
      exact = @plugin.find_zone('us/pacific')
      expect(exact.length).to eql(1)
      expect(exact[0].name).to eql('US/Pacific')

      multiple = @plugin.find_zone('pacific')
      expect(multiple.length).to be > 1
    end
  end
end

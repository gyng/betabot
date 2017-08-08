require 'spec_helper'
require_relative '../showtime.rb'

describe Bot::Plugin::Showtime do
  before(:each) do
    @plugin = Bot::Plugin::Showtime.new(nil)
  end

  describe '#valid_anilist_token?' do
    it 'checks for empty token' do
      empty_token = {
        token: nil
      }
      @plugin.instance_variable_set(:@anilist, empty_token)
      expect(@plugin.valid_anilist_token?).to be false
    end

    it 'checks for expired token' do
      expired_token = {
        token: {
          expires: Time.now.to_i - 1
        }
      }
      @plugin.instance_variable_set(:@anilist, expired_token)
      expect(@plugin.valid_anilist_token?).to be false
    end

    it 'checks for valid token' do
      valid_token = {
        token: {
          expires: Time.now.to_i + 1
        }
      }
      @plugin.instance_variable_set(:@anilist, valid_token)
      expect(@plugin.valid_anilist_token?).to be true
    end
  end
end

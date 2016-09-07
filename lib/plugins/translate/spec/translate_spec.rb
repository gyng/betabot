require 'spec_helper'
require 'bing_translator'
require_relative '../translate.rb'

describe Bot::Plugin::Translate do
  subject do
    plugin = Bot::Plugin::Translate.new(nil)
    plugin.instance_variable_set(
      :@s,
      bing_client_id: true,
      bing_api_key: true,
      azure_account_key: true,
      default_target_locale: :en
    )
    plugin
  end

  it 'translates from a source locale to a target locale' do
    message = Bot::Core::Message.new { |m| m.text = 'translate en ja I love betabot' }

    expect(subject.instance_variable_get(:@translator))
      .to receive(:translate)
      .with('I love betabot', from: 'en', to: 'ja')

    subject.translate(message)
    sleep 0.05 # translate is called inside a thread
  end

  it 'translates if no locales are given' do
    message = Bot::Core::Message.new { |m| m.text = 'translate I love betabot too' }

    expect(subject.instance_variable_get(:@translator))
      .to receive(:translate)
      .with('I love betabot too', to: :en)

    subject.translate(message)
    sleep 0.05 # translate is called inside a thread
  end
end

module Fixtures
  module Bot
    def settings_filename_fixture
      File.absolute_path "spec/fixtures/data/bot_settings_fixture.json"
    end

    def settings_fixture
      JSON.parse(File.read("spec/fixtures/data/bot_settings_fixture.json"), symbolize_names: true)
    end

    def whitelist_settings_fixture
    end

    def blacklist_settings_fixture
    end
  end
end
module Fixtures # rubocop:disable Style/ClassAndModuleChildren
  module Bot
    def settings_filename_fixture
      File.absolute_path('spec/fixtures/data/bot_settings_fixture.json')
    end

    def settings_filename_whitelist_fixture
      File.absolute_path('spec/fixtures/data/bot_settings_whitelist_fixture.json')
    end

    def settings_filename_blacklist_fixture
      File.absolute_path('spec/fixtures/data/bot_settings_blacklist_fixture.json')
    end

    def settings_fixture
      JSON.parse(File.read(settings_filename_fixture), symbolize_names: true)
    end

    def settings_whitelist_fixture
      JSON.parse(File.read(settings_filename_whitelist_fixture), symbolize_names: true)
    end

    def settings_blacklist_fixture
      JSON.parse(File.read(settings_filename_blacklist_fixture), symbolize_names: true)
    end
  end
end

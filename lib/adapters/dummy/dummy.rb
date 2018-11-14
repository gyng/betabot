class Bot::Adapter
  attr_accessor :handler

  # Dummy adapter for testing purposes
  class Dummy < Bot::Adapter
    def initialize(bot)
      super
    end
  end
end

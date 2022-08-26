class Bot::Adapter
  attr_accessor :handler

  # Dummy adapter for testing purposes
  class Dummy < Bot::Adapter
  end
end

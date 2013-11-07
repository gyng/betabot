module Bot
  module Adapters
    class Dummy < Bot::Adapter
      def initialize
        @name = 'test'
        Bot.log.info("Loaded adapter #{self.class.name}")
      end
    end
  end
end
module Bot
  class << self
    attr_accessor :log

    def log
      if !@log
        @log = Logger.new(STDOUT)
        @log.level = Logger::WARN if ENV['TEST'] # Set in spec_helper.rb
        @log.formatter = -> severity, datetime, progname, message do
          color = case severity
            when 'FATAL';   :red
            when 'ERROR';   :red
            when 'WARN';    :red
            when 'INFO';    :gray
            when 'DEBUG';   :gray
            when 'UNKNOWN'; :gray
          end
          "#{(severity[0] + ' ' + datetime.to_s + ' | ').send(color)}#{message}\n"
        end
      end
      @log
    end
  end
end
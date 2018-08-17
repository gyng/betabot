module Bot
  class << self
    def log
      unless @log
        @log = Logger.new(STDOUT)
        @log.level = Logger::WARN if ENV['TEST'] # Set in spec_helper.rb
        @log.formatter = lambda do |severity, datetime, _progname, message|
          color_table = {
            'FATAL' => :red,
            'ERROR' => :red,
            'WARN' => :red,
            'INFO' => :gray,
            'DEBUG' => :gray,
            'UNKNOWN' => :gray
          }
          color = color_table[severity]
          "#{(severity[0] + ' ' + datetime.to_s + ' | ').send(color)}#{message}\n"
        end
      end
      @log
    end
  end
end

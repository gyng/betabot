require 'sinatra/base'
require 'thin'

def start_web(s)
  Web.url = s[:link_url]
  hudda_app = Web.new
  start_sinatra s, hudda_app
  hudda_app
end

def start_sinatra(s, web_app)
  server  = s[:server]    || 'thin'
  host    = s[:host]      || '0.0.0.0'
  port    = s[:port].to_s || '80'

  dispatch = Rack::Builder.app do
    map '/' do
      run web_app
    end
  end

  Rack::Server.start(
    app: dispatch,
    server: server,
    Host: host,
    Port: port,
    signals: false
  )
end

class Web < Sinatra::Base
  class << self
    attr_accessor :url
  end

  configure do
    set :threaded, true
    set :public_folder, 'lib/public'
    set :show_exceptions, false
  end
end

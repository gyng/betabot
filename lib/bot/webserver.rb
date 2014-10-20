require 'sinatra/base'
require 'thin'

def start_web(s)
  start_sinatra app: (hudda_app = Web.new)
  hudda_app
end

def start_sinatra(s)
  server  = s[:server] || 'thin'
  host    = s[:host]   || '0.0.0.0'
  port    = s[:port]   || '8888'
  web_app = s[:app]
  Web.url = s[:link_url]

  dispatch = Rack::Builder.app do
    map '/' do
      run web_app
    end
  end

  Rack::Server.start({
    app:    dispatch,
    server: server,
    Host:   host,
    Port:   port
  })
end

class Web < Sinatra::Base
  configure do
    set :threaded, false
    set :public_folder, 'lib/public'
    set :show_exceptions, true
  end
end

require 'sinatra'
require 'haml'

$siteTitle = 'Matt Hamilton'

helpers do
  include Rack::Utils

  def h(source)
    escape_html(source).gsub(' ', '%20')
  end
end

set :haml, :format => :html5

get '/' do
	haml :recent
end
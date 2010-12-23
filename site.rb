require 'sinatra'
require 'haml'
require 'rest_client'
require 'json'

$siteTitle = 'Site Name'

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
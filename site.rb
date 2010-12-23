require 'sinatra'
require 'haml'
require 'couchrest'

if ENV['CLOUDANT_URL']
  set :db, CouchRest.database!( ENV['CLOUDANT_URL'] + '/redback' )
  set :views, File.dirname(__FILE__) + '/views'
  set :public, File.dirname(__FILE__) + '/public'
else
  set :db, CouchRest.database!( 'http://localhost:5984/redback' )
end

helpers do
  include Rack::Utils

  def h(source)
    escape_html(source).gsub(' ', '%20')
  end
  
  def initiate_settings()
    begin
      @settings = options.db.get('settings')
    rescue RestClient::ResourceNotFound
      options.db.save_doc({'_id' => 'settings', :SiteTitle => 'Redback Site', :Author => 'Not set',
                            :SiteDescription => 'Not set', :SiteKeywords => 'Not set'})
      @settings = options.db.get('settings')
    end
        
      $siteTitle = @settings['SiteTitle']
      $author = @settings['Author']
      $siteDescription = @settings['SiteDescription']
      $siteKeywords = @settings['SiteKeywords']
      end
end

set :haml, :format => :html5

initialize

get '/' do
    initiate_settings
    @posts = options.db.view('posts/all')['rows']
    haml :recent
end



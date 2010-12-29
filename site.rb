require 'sinatra'
require 'haml'
require 'openssl'
require 'digest/sha2'
require 'couchrest'

if ENV['CLOUDANT_URL']
  set :db, CouchRest.database!( ENV['CLOUDANT_URL'] + '/redback' )
  set :views, File.dirname(__FILE__) + '/views'
  set :public, File.dirname(__FILE__) + '/public'
else
  set :db, CouchRest.database!( 'http://localhost:5984/redback' )
end

$pass = 'redback'

enable :sessions

class Pass
  attr_accessor :salt, :key, :encrypted, :decrypted
  
  def encryptnew(plainText)
    c = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
    c.encrypt
    c.key = Digest::SHA512.digest($siteKey)
    c.iv = @salt = c.random_iv
    p = Digest::SHA512.digest(@salt + '--' + plainText)
    encryptedText = c.update(p)
    encryptedText << c.final
    $salt = @salt
    @encrypted = encryptedText
  end

  def encrypt(plainText, salt)
    c = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
    c.encrypt
    c.key = Digest::SHA512.digest($siteKey)
    c.iv = salt
    p = Digest::SHA512.digest(@salt + '--' + plainText)
    encryptedText = c.update(p)
    encryptedText << c.final
    @encrypted = encryptedText
  end
end


helpers do
  include Rack::Utils

  def h(source)
    escape_html(source).gsub(' ', '%20')
  end

  def utcdatetime
    Time.now.utc
  end
  
  def protected!
    unless authorized?
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    if $password == "" 
      true
    end  
    session[:pass] == $password
  end
  
  def login(password)
    p = Pass.new
    if $password == p.encrypt(password, $salt)
        session[:pass] = $password
        true
    else
        session[:pass] = nil
        false
    end
  end
  
end

set :haml, :format => :html5

get '/' do
    begin
      @settings = options.db.get('settings')
#      @settings = {'_id' => 'settings', :SiteTitle => 'Redback Site', :Author => 'Not set', :SiteDescription => 'Not set', :SiteKeywords => 'Not set'}
      $siteTitle = @settings['SiteTitle']
      $author = @settings['Author']
      $siteDescription = @settings['SiteDescription']
      $siteKeywords = @settings['SiteKeywords']
      $siteKey = 'RedbackBlog'
      $password = @settings['Password']
      $salt = @settings['Salt']
    rescue RestClient::ResourceNotFound
      options.db.save_doc({'_id' => 'settings', :SiteTitle => 'Redback Site', :Author => 'Not set', :SiteDescription => 'Not set', :SiteKeywords => 'Not set'})
      @settings = options.db.get('settings')
      @settings = {'_id' => 'settings', :SiteTitle => 'Redback Site', :Author => 'Not set', :SiteDescription => 'Not set', :SiteKeywords => 'Not set'}
      $siteTitle = settings['SiteTitle']
      $author = settings['Author']
      $siteDescription = settings['SiteDescription']
      $siteKeywords = settings['SiteKeywords']
    end

    @posts = options.db.view('posts/all')['rows']
    haml :recent
end

get '/feed' do
end

get '/feeds/:name' do
    protected!
    @name = params[:name]
    haml :test
end

get '/commentfeed' do
end

get '/login' do
    haml :login, :layout => :privateLayout
end

post '/login' do
    @result = login(params[:password])
    if authorised?
        redirect '/admin'
    else
        @error = 'Password incorrect'
        haml :login, :layout => :privateLayout
    end
end

get '/admin' do
    haml :admin, :layout => :privateLayout
end

get '/robots' do
end

get '/status' do
end

get '/sitemap' do
end

get '/unpublished' do
end

get '/search' do
end

get '/new' do
end

get '/edit/:page' do
end

get '/revert/:page/:revision' do
end

get %r{/(\d+)} do
    begin
      i = Integer(params[:captures].join)
      'page number ' + i.to_s
    rescue Exception::ArgumentError
      pass
    end    
end

get '/:page/via-feed' do
end

get '/:page/revisions' do
end

get '/:page/:revision' do
end
    
not_found do
    'Oh snap! That page doesn\'t exist!'
end

error do
	'Oh noes, there was an error. Don\'t worry, our code monkies will look into it'
end
['sinatra', 'haml', 'couchrest', 'uri', 'net/http', 'maruku'].each {|gem| require gem}

require './models/entry.rb'
require './models/akismet.rb'

if ENV['CLOUDANT_URL']
  set :db, CouchRest.database!( ENV['CLOUDANT_URL'] + '/redback' )
  set :views, File.dirname(__FILE__) + '/views'
  set :public, File.dirname(__FILE__) + '/public'
else
  set :db, CouchRest.database!( 'http://localhost:5984/redback' )
end

$siteinitialized = false
$installing = false
$installed = false

$itemsperpage = 30

enable :sessions

helpers do
  include Rack::Utils

  def initializesite
      if $siteinitialized == false
        @settings = options.db.get('settings')
        $siteTitle = @settings['SiteTitle']
        $siteUrl = @settings['SiteUrl']
        $author = @settings['Author']
        $introduction = @settings['Introduction']
        $siteDescription = @settings['SiteDescription']
        $siteKeywords = @settings['SiteKeywords']
        $mainLinks = @settings['MainLinks']
        $siteFooter = @settings['SiteFooter']
        $siteTheme = @settings['SiteTheme']
        $uploadPath = @settings['UploadPath']
        $akismetApiKey = @settings['AkismetApiKey']
        $htmlhead = @settings['HtmlHead']
        $htmlfoot = @settings['HtmlFoot']
        $commentNotification = @settings['CommentNotification']
        $smtpServer = @settings['SmtpServer']
        $smtpPort = @settings['SmtpPort']
        $smtpUseSsl = @settings['SmtpUseSsl']
        $smtpFromEmailAddress = @settings['SmtpFromEmailAddress']
        $smtpToEmailAddress = @settings['SmtpToEmailAddress']
        $smtpUsername = @settings['SmtpUsername']
        $smtpPassword = @settings['SmtpPassword']
        $password = @settings['Password']
        $siteinitialized = true
      end
  end
  
  def reinitializesite
    $siteinitialized = false
    initializesite
  end
  
  def h(source)
    escape_html(source).gsub(' ', '-')
  end

  def utcdatetime
    Time.now.utc
  end
  
  def feedschecked(value)
    value == true ? "checked" : ""
  end
  
  def getposts(page)
    p = options.db.view('posts/total_posts')['rows']
    numposts = p.nil? ? p.first['value'] : 0
    pages = (numposts / $itemsperpage).ceil
    posts = options.db.view('posts/by_postdate', {:skip => $itemsperpage * page, :limit => $itemsperpage, :descending => true})['rows']
    return page, pages, posts
  end
  
  def getthemes
    directory = 'public/styles/themes/'
    themes = Array.new
    Dir.entries(directory).each do |d|
        unless File.directory?(d) 
            themes << d
        end  
    end
    themes
  end
  
  def protected!
    unless authorized?
      redirect '/login'
    end
  end

  def authorized?
    session[:pass] == $password ? true : false
  end
  
  def login(password)
    if $password == password
        session[:pass] = $password
        true
    else
        session[:pass] = nil
        false
    end
  end
  
  def logout
    session[:pass] = nil
  end
end

set :haml, :format => :html5

before do
    if $installing == false and $installed == false
        begin
            @settings = options.db.get('settings')
        rescue         
            $installing = true
            redirect '/installation'
        end
    end
    $installed = true
    if $installing == false and $installed == true
       initializesite
    end
end

get '/installation' do
    $siteTheme = 'RainbowAfro'
    options.db.save_doc({'_id' => '_design/posts', 
        'views' => { 'all' => { 'map' => "function(doc) { if (doc.Type == 'post') emit(doc._id, doc); }" },
        'by_postdate' => { 'map' => "function(doc) { if (doc.Type == 'post') emit(doc.PublishDate, doc); }" },
        'total_posts' => { 'map' => "function(doc) { if (doc.Type == 'post') emit('posts', 1); }", 'reduce' => "function(keys, values, rereduce) { return sum(values); }" }}})
    options.db.save_doc({'_id' => '_design/feeds',
        'views' =>  { 'all' => { 'map' => "function(doc) { if (doc.Type == 'feed') emit(doc._id, doc); }" }}})
    options.db.save_doc({'_id' => 'settings',
        'MainLinks' => '<li><a href="/about">About</a></li>',
        'SiteDescription' => 'My website.',
        'SiteUrl' => 'http://your-site.com/',
        'SmtpUsername' => '',
        'HtmlHead' => '',
        'CommentNotification' => true,
        'SmtpPort' => '21',
        'Author' => 'Daffy Duck',
        'SiteFooter' => '<p>Powered by <a href="https://github.com/andrewtobin/redback">Redback</a> a Ruby port of the <a href="http://www.funnelweblog.com">FunnelWeb</a> blog engine.</p>',
        'Introduction' => 'Welcome to your Redback blog. You can <a href="/login">login</a> and edit this message in the administration section. The default password is <code>test</code>.',
        'SmtpFromEmailAddress' => 'redback@your-site.com',
        'AkismetApiKey' => '37726b9324fe',
        'SmtpPassword' => '',
        'Password' => 'test',
        'HtmlFoot' => '',
        'SmtpServer' => '',
        'SmtpUseSsl' => false,
        'SiteTitle' => 'My Redback Site',
        'SiteKeywords' => 'test, Ruby, Development, Software, Programming, Redback',
        'SiteTheme' => 'RainbowAfro',
        'UploadPath' => '~/files',
        'SmtpToEmailAddress' => 'you@your-site.com'})

    $installing = false
    $installed = true
    
    reinitializesite
    
    haml :install, :layout => :installLayout
end

get '/' do
    @page, @pages, @posts = getposts(0)
    haml :recent
end

get '/feed' do
end

get '/feeds/:name' do
end

get '/commentfeed' do
end

get '/login' do
    haml :login, :layout => :privateLayout
end

post '/login' do
    @result = login(params[:password])
    if authorized?
        redirect '/admin'
    else
        @error = 'Password incorrect'
        haml :login, :layout => :privateLayout
    end
end

get '/logout' do
    logout
    redirect '/'
end

get '/admin' do
    protected!
    haml :admin, :layout => :privateLayout
end

get '/admin/settings' do
    protected!
       
    @themes = getthemes
    @settings = options.db.get('settings')
    haml :settings, :layout => :privateLayout
end

post '/admin/settings' do
    protected!
    @settings = options.db.get('settings')

    @settings['SiteTitle'] = params[:SiteTitle]
    @settings['SiteUrl'] = params[:SiteUrl]
    @settings['Author'] = params[:Author]
    @settings['Introduction'] = params[:Introduction]
    @settings['SiteDescription'] = params[:SiteDescription]
    @settings['SiteKeywords'] = params[:SiteKeywords]
    @settings['MainLinks'] = params[:MainLinks]
    @settings['SiteFooter'] = params[:SiteFooter]
    @settings['SiteTheme'] = params[:SiteTheme]
    @settings['UploadPath'] = params[:UploadPath]
    @settings['AkismetApiKey'] = params[:AkismetApiKey]
    @settings['HtmlHead'] = params[:HtmlHead]
    @settings['HtmlFoot'] = params[:HtmlFoot]
    @settings['CommentNotification'] = params[:CommentNotification]
    @settings['SmtpServer'] = params[:SmtpServer]
    @settings['SmtpPort'] = params[:SmtpPort]
    @settings['SmtpUseSsl'] = params[:SmtpUseSsl]
    @settings['SmtpFromEmailAddress'] = params[:SmtpFromEmailAddress]
    @settings['SmtpToEmailAddress'] = params[:SmtpToEmailAddress]
    @settings['SmtpUsername'] = params[:SmtpUsername]
    @settings['SmtpPassword'] = params[:SmtpPassword]
        
    @settings.save()
    
    reinitializesite
    redirect '/admin'
end

get '/admin/feeds' do
    protected!
       
    @feeds = options.db.view('feeds/all')['rows']
    haml :feeds, :layout => :privateLayout
end

post '/admin/feeds' do
    protected!
    
    options.db.save_doc({'_id' => h(params[:FeedName]), :Name => params[:FeedName], :Title => params[:FeedTitle], :Type => 'feed'})
    redirect '/admin/feeds'
end

get '/admin/deletefeed/:feed' do
    protected!
    
    @feeds = options.db.get(params[:feed])
    @feeds.destroy()
    
    redirect '/admin/feeds'
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

get '/restart' do
    reinitializesite
    redirect '/'
end

get '/new' do
    protected!
    redirect '/edit/new'
end

get '/edit/:page' do
    protected!
    
    if params[:page] == 'new'
        @entry = Entry.new
        @entry.Title = 'Enter a title'
        @entry.IsDiscussionEnabled = true
        @entry.MetaTitle = 'Enter a meta title'
        @entry.PublishDate = Time.now.strftime('%Y-%m-%d')
        @entry.IsNew = true
    else
        @post = options.db.get(h(params[:page]))
        
        @entry = Entry.new

        @entry.Name = @post['Name']
        @entry.Title = @post['Title']
        @entry.Summary = @post['Summary']
        @entry.MetaTitle = @post['MetaTitle']
        @entry.MetaDescription = @post['MetaDescription']
        @entry.MetaKeywords = @post['MetaKeywords']
        @entry.PublishDate = @post['PublishDate']
        @entry.Content = @post['Content']
        @entry.Reason = @post['Reason']
        @entry.IsDiscussionEnabled = @post['IsDiscussionEnabled']
        
        @entry.IsNew = false
    end
    
    haml :edit, :layout => :privateLayout
end

post '/edit/:page' do
    protected!

    if params[:IsNew] == 'true'
        @entry = Entry.new
   
        @entry.Name = params[:Name]
        @entry.Title = params[:Title]
        @entry.Summary = params[:Sidebar]
        @entry.MetaTitle = params[:MetaTitle]
        @entry.IsDiscussionEnabled = params[:AllowedComments]
        @entry.MetaDescription = params[:MetaDescription]
        @entry.MetaKeywords = params[:Keywords]
        @entry.PublishDate = Time.now.utc
        @entry.Content = params[:Content]
        @entry.Reason = params[:ChangeSummary]
     
        options.db.save_doc({'_id' => h(params[:Name]), :Name => @entry.Name, :Title => @entry.Title, :Summary => @entry.Summary,
            :PublishDate => @entry.PublishDate, :IsDiscussionEnabled => @entry.IsDiscussionEnabled, 
            :MetaTitle => @entry.MetaTitle, :MetaDescription => @entry.MetaDescription, :MetaKeywords => @entry.MetaKeywords, 
            :Reason => @entry.Reason, :Content => @entry.Content, :Type => 'post'})
    else
        @entry = options.db.get(h(params[:Name]))

        @entry['Name'] = params[:Name]
        @entry['Title'] = params[:Title]
        @entry['Summary'] = params[:Sidebar]
        @entry['MetaTitle'] = params[:MetaTitle]
        @entry['IsDiscussionEnabled'] = params[:AllowedComments]
        @entry['MetaDescription'] = params[:MetaDescription]
        @entry['MetaKeywords'] = params[:Keywords]
        @entry['PublishDate'] = Time.now.utc
        @entry['Content'] = params[:Content]
        @entry['Reason'] = params[:ChangeSummary]
        
        @entry.save()
    end
            
    redirect '/' + h(params[:Name])
end

get '/revert/:page/:revision' do
end


get %r{/(\d+)} do
    begin
      page = Integer(params[:captures].join)
      @page, @pages, @posts = getposts(page)
      haml :recent
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

get '/:pageTitle' do
    begin
        @entry = options.db.get(params[:pageTitle])
        haml :entry
    rescue
        'Bee!'
        #redirect not_found
    end
end
    
not_found do
    'Oh snap! That page doesn\'t exist!'
end

error do
	'Oh noes, there was an error. Don\'t worry, our code monkies will look into it'
end
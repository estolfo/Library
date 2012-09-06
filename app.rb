require 'sinatra'
require './helpers/sinatra'
require './model/mongodb'
require 'haml'
require 'digest/md5'


configure do
  enable :sessions
  @@server_version = DB.connection.server_version
  @@mongo_gem_version = Gem.loaded_specs["mongo"].version.to_s
  # set up indexes. Run this before starting the app
  #DB['authors'].create_index("slug", {:unique => true }) # unique index on user and slug
  #DB['books'].create_index([["user", Mongo::ASCENDING], ["slug", Mongo::ASCENDING ]], {:unique => true }) # TODO user should be indexes in ascending order?
end

# TODO if session[:user] == nil
before do
  unless session[:user] == nil
    @user = session[:user]
  end
end

get '/' do
  if logged_in?
    @book_count = BOOKS.find({:user => @user._id}).count
    
    if @@server_version > '2.1.1' and @@mongo_gem_version >= '1.7.0'
      puts "using aggregation framework"
      authors = BOOKS.aggregate([
                {"$match" => {"user" => @user._id }}, 
                {"$project" => {"author" => 1}}, 
                {"$group" => {"_id" => "$author", "book_count" =>  { "$sum" => 1}}} 
              ])
      @author_count = authors.length
    else
      puts "using group function"
      authors = BOOKS.group(
                      { :cond => {"user" => @user._id }, 
      	                :key => "author",
                        :initial =>{:book_count => 0},
                        :reduce => "function(doc, out){ 
                                    var author = db.authors.findOne(doc.author);
                                    out.book_count++; }"
                      } )
      @author_count = authors.length
    end
    
    haml :user_dashboard
  else
    haml :index
  end
end

get '/user' do
  redirect '/user/' + session[:user].email + '/profile'
end

get '/about' do
  haml :about
end

get '/login' do
  haml :login
end

post '/login' do
  if session[:user] = User.auth(params["email"], params["password"])
    flash("Login successful")
    redirect "/user/" << session[:user].email << "/dashboard"
  else
    flash("Login failed - Try again")
    redirect '/login'
  end
end

get '/logout' do
  session[:user] = nil
  flash("Logout successful")
  redirect '/'
end

get '/register' do
  haml :register
end

post '/register' do
  u            = User.new
  u.email      = params[:email]
  u.password   = params[:password]
  u.name       = params[:name]
  u.email_hash = Digest::MD5.hexdigest(params[:email].downcase)

  if u.save()
    flash("User created")
    session[:user] = User.auth( params["email"], params["password"])
    redirect '/user/' << session[:user].email.to_s << "/dashboard"
  else
    tmp = []
    u.errors.each do |e|
      tmp << (e.join("<br/>"))
    end
    flash(tmp)
    redirect '/create'
  end
end

get '/user/:email/dashboard' do
  @book_count = BOOKS.find().count
  @author_count = AUTHORS.find().count
  haml :user_dashboard
end

get '/user/:email/profile' do
  @user = User.new_from_email(params[:email])
  haml :user_profile
end

#get '/list' do
#  @users = Users.find
#  haml :list
#end

# get list of books
get '/books' do
  books
end

# new book form
get '/books/new' do
  haml :new_book
end

post '/books' do
  b               = {}
  b[:title]       = params[:title].strip
  b[:isbn]        = params[:isbn].strip
  b[:pages]       = params[:pages].strip.to_i
  b[:publisher]   = {}
  b[:publisher][:publisher_name] = params[:publisher_name].strip

  b[:publisher][:publisher_city] = params[:publisher_city].strip.capitalize
  b[:available]   = params[:available].nil? ? false : true
  b[:user]        = session[:user]._id

  # handle author
  author_first  = params[:author_first].strip.downcase.gsub(' ', '-')
  author_last   = params[:author_last].strip.downcase.gsub(' ', '-')
  author_slug   = [ author_first, author_last ].join('-')

  response = AUTHORS.update( {:slug => author_slug },
                         { :$set => {  :first_name => params[:author_first].strip.capitalize, 
                                       :last_name => params[:author_last].strip.capitalize,
                                       :slug => author_slug } },
                         {:upsert => true, :safe => true }
  )

  if response["updatedExisting"]
    print "updated existing author"
    b[:author] = DB['authors'].find_one(:slug => author_slug)["_id"]
  else
    print "created new author"
    b[:author] = response["upserted"]
  end

  # generate slug
  book_title  = b[:title].downcase.gsub(' ', '-')
  book_isbn   = b[:isbn].downcase.gsub(' ', '')
  if book_isbn.empty?
    book_slug = book_title
  else
    book_slug = [ book_isbn, book_title ].join("-")
  end

   # handle date
   #b[:publisher][:published_date] =
   #time_for('Dec 23, 2012')
 
  response = BOOKS.update( {:slug => book_slug, :user => @user._id },
                       { :$set => {  :title      => b[:title], 
                                     :isbn       => b[:isbn],
                                     :pages      => b[:pages],
                                     :publisher  => b[:publisher],
                                     :user       => b[:user],
                                     :available  => b[:available],
                                     :author     => b[:author] } },
                         {:upsert => true, :safe => true }
   )
   flash("book created")
   redirect '/books'
end

# see one book
get '/books/:slug' do 
  @book = BOOKS.find_one({:slug => params[:slug], :user => @user._id })
  haml :book
end

# enter a review for one book
get '/books/:slug/review' do 
  @book = BOOKS.find_one({:slug => params[:slug], :user => @user._id })
  haml :book_review
end

# submit a review for one book
post '/books/:slug/review' do 
  @book = BOOKS.find_one({:slug => params[:slug], :user => @user._id })
  
  # save review and rating
  
  redirect "/books/" + @book["slug"]
end

get '/authors' do
  @authors = BOOKS.group(
                  { :cond => {"user" => @user._id }, 
  	                :key => "author",
                    :initial =>{:books => [], :author_info => {}},
                    :reduce => "function(doc, out){ 
                                var author = db.authors.findOne(doc.author);
                                out.author_info = {first_name: author.first_name, last_name: author.last_name};
                                out.books.push({title: doc.title, slug : doc.slug}); };"
                  } )

  haml :author_index
end

get '/authors/*-*/books' do |first, last|
  #puts "first name #{first}, last: #{last}"
end

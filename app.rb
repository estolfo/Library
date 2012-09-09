require 'sinatra'
require './helpers/library_helpers'
require './model/mongodb'
require 'haml'
require 'digest/md5'


configure do
  enable :sessions
  @@server_version = DB.connection.server_version
  @@mongo_gem_version = Gem.loaded_specs["mongo"].version.to_s
  # set up indexes. Run this before starting the app
  #DB['users'].create_index("email", {:unique => true })
  #DB['authors'].create_index("slug", {:unique => true }) # unique index on slug
  #DB['books'].create_index("slug", {:unique => true }) # TODO user should be indexes in ascending order?
end


before /^(?!\/(home|register|login))/ do
  unless session[:user]
    redirect '/home'
  else
    @user = session[:user]
    @user["email_hash"] = Digest::MD5.hexdigest(@user["email"].downcase)
  end
end

get '/home' do
  @user = session[:user]
  unless @user == nil
    @book_count = BOOKS.find().count
    
    if @@server_version > '2.1.1' and @@mongo_gem_version >= '1.7.0'
     puts "using aggregation framework"
     authors = BOOKS.aggregate([
               {"$match" => {"author" => {"$exists" => true } } },
               {"$project" => {"author" => 1 } }, 
               {"$group" => {"_id" => "$author", "book_count" =>  { "$sum" => 1 } } } 
             ])
     @author_count = authors.length
   else
     puts "using group function"
     authors = BOOKS.group(
                     { :key => "author",
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
  if @user["email"].nil?
    redirect '/home'
  else
    redirect '/home/' + @user["email"] + '/profile'
  end
end

get '/about' do
  haml :index
end

get '/login' do
  haml :login
end

post '/login' do
  if params[:email]
    session[:user] = USERS.find_one({:email => params[:email] } )
    if session[:user].nil?
      flash("Login failed - Try again")
      redirect '/login'
    end
  else
    flash("Login failed - Try again")
    redirect '/login'
  end

  redirect "/user/" << session[:user]["email"] << "/dashboard"

end

get '/logout' do
  session[:user] = nil
  flash("Logout successful")
  redirect '/home'
end

get '/register' do
  haml :register
end

post '/register' do
  u            = {}
  u[:email]      = params[:email]
  u[:name]       = params[:name]
  
  if USERS.find_one({:email => u[:email] }).nil?
    
    if USERS.save(u)
      flash("User created")
      redirect '/login'
    
    else
      flash("User not created")
      redirect '/register'
    end
      
  else
      flash("Email already taken, try another one.")
      redirect '/register'
  end
  
end

get '/user/:email/dashboard' do
  @book_count = BOOKS.find().count
  @author_count = AUTHORS.find().count
  haml :user_dashboard
end

get '/user/:email/profile' do
  haml :user_profile
end

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
  b[:created_by]  = @user.nil? ? "" : @user["_id"]

  # handle author
  unless params[:author_first].empty? and params[:author_last].empty?
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
 
  response = BOOKS.update( {:slug => book_slug },
                       { :$set => {  :title      => b[:title], 
                                     :isbn       => b[:isbn],
                                     :pages      => b[:pages],
                                     :publisher  => b[:publisher],
                                     :created_by => b[:created_by],
                                     :available  => b[:available],
                                     :author     => b[:author] } },
                         {:upsert => true, :safe => true }
   )
   
   if response["updatedExisting"]
     flash("Updated existing book")
   else
     flash("New book created")
   end
   
   redirect '/books'
end

# see one book
get '/books/:slug' do 
  @book = BOOKS.find_one({:slug => params[:slug] })
  haml :book
end

# enter a note for one book
get '/books/:slug/notes' do 
  @book = BOOKS.find_one({:slug => params[:slug]})
  haml :book_note
end

# submit a note for one book
post '/books/:slug/notes' do 
  note = {:user => @user["_id"], :note => params[:note] }
  @book = BOOKS.find_and_modify({ :query => {:slug => params[:slug] },
                                     :update => { :$push => { :notes => note } } ,
                                     :new => true } )
  redirect "/books" if @book.nil?
  redirect "/books/" + @book["slug"]
end

get '/authors' do
  @authors = BOOKS.group(
                  { :key => "author",
                    :initial =>{:books => [], :author_info => {}},
                    :reduce => "function(doc, out){
                                if (doc.author != null) {
                                  var author = db.authors.findOne(doc.author);
                                  out.author_info = {first_name: author.first_name, last_name: author.last_name};
                                  out.books.push({title: doc.title, slug : doc.slug}); 
                                  };
                                }"
                  } )

  haml :author_index
end
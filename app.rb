require 'sinatra'
require './helpers/sinatra'
require './model/mongodb'
require 'haml'
require 'digest/md5'


configure do
  enable :sessions
end

before do
  unless session[:user] == nil
    @user = session[:user]
  end
end

def books
  @books = BOOKS.find({:user => @user._id }).sort([:title, :ascending])
  haml :books_index
end

get '/' do
  if logged_in?
    books
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
  haml :user_dashboard
end

get '/user/:email/profile' do
  @user = User.new_from_email(params[:email])
  haml :user_profile
end

get '/list' do
  @users = Users.find
  haml :list
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

  print "book slug: #{book_slug}"
   # handle date
   #b[:publisher][:published_date] =
 
  response = BOOKS.update( {:slug => book_slug },
                       { :$set => {  :title      => b[:title], 
                                     :isbn       => b[:isbn],
                                     :pages      => b[:pages],
                                     :publisher  => b[:publisher],
                                     :user       => b[:user],
                                     :available  => b[:available] } },
                         {:upsert => true, :safe => true }
   )
   flash("book created")
   redirect '/books'
end

get '/authors' do

end

get '/authors/*-*/books' do |first, last|
  puts "first name #{first}, last: #{last}"
  
end

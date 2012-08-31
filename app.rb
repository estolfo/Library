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
    @suser = session[:user]
  end
end

get '/' do
  haml :index
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
  puts session[:user]
  
end

post '/books/' do
  #  	_id: ObjectId
  #  	title: UTF-8 string
  #  	author: ObjectId
  #  	ISBN: UTF-8 string
  #  	available: Boolean
  #  	publisher: Embedded document
  #  		publisher_name: UTF-8 string
  #  		date: Timestamp
  #  		city: UTF-8 string
  #  	pages: 32-bit Integer
  #  	summary: UTF-8 string
  #  	subjects: Array
  #  		UTF-8 strings
  #  	notes: Array
  #  		Documents
  #  			user: ObjectId
  #  			note: UTF-8 string
  #  	language: UTF-8 string
end

get '/authors' do

end

get '/authors/*-*/books' do |first, last|
  puts "first name #{first}, last: #{last}"
  
  
end

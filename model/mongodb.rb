require 'mongo'
require './model/mongoModule'
require './model/user'

connection = Mongo::Connection.new("localhost", 27017)
DB         = connection.db('library')
USERS      = DB['users']
BOOKS      = DB['books']
AUTHORS    = DB['authors'] 

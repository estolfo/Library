require 'mongo'
require './model/mongoModule'
require './model/user'

connection = Mongo::Connection.new("localhost", 27017)
DB         = connection.db('library')
USERS      = DB['users']
BOOKS      = DB['books']
AUTHORS    = DB['authors'] 

DB['authors'].create_index("slug", {:unique => true }) # unique index on slug
DB['books'].create_index("slug", {:unique => true }) # unique index on slug
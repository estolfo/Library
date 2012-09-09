require 'mongo'

connection = Mongo::Connection.new(URI.parse(ENV['DATABASE_URL'] || 'localhost'))
DB         = connection.db('library')
USERS      = DB['users']
BOOKS      = DB['books']
AUTHORS    = DB['authors'] 

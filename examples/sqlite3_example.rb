# frozen_string_literal: true

require 'sqlite3'
require 'sqlite_web_vfs'
require 'uri'

chinook_url = 'https://github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite.sqlite'
encoded_url = URI.encode_www_form_component(chinook_url)
web_uri = "file:/__web__?vfs=web&mode=ro&immutable=1&web_url=#{encoded_url}"

db = SQLite3::Database.new(':memory:')
SQLiteWebVFS::Loader.load(db)
puts '✅ HTTP VFS extension loaded.'

db.execute('ATTACH DATABASE ? AS remote', [web_uri])
puts "✅ Remote database attached as 'remote'."

album_count = db.get_first_value('SELECT COUNT(*) FROM remote.Album')
puts "💿 Found #{album_count} albums in the remote Chinook database."

db.close

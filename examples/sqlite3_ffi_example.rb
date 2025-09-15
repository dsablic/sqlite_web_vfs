begin
  require 'sqlite3-ffi'
rescue LoadError
  require 'sqlite3/ffi'
end
require 'sqlite_web_vfs'
require 'uri'

chinook_url = "https://github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite.sqlite"
encoded_url = URI.encode_www_form_component(chinook_url)
web_uri = "file:/__web__?vfs=web&mode=ro&immutable=1&web_url=#{encoded_url}"

db = SQLite3::Database.new(':memory:')
SQLiteWebVFS::Loader.load(db)
puts "✅ HTTP VFS extension loaded into FFI driver."

db.execute("ATTACH DATABASE ? AS remote", [web_uri])
puts "✅ Remote database attached as 'remote'."

album_count = db.execute("SELECT COUNT(*) FROM remote.Album").first.first
puts "💿 Found #{album_count} albums in the remote Chinook database."

db.close

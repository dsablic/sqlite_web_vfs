# frozen_string_literal: true

require 'uri'
require_relative '../spec_helper'
require 'sqlite_web_vfs'

RSpec.describe SQLiteWebVFS do
  let(:chinook_url) { ENV['CHINOOK_URL'] || 'https://github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite.sqlite' }
  let(:encoded_url) { URI.encode_www_form_component(chinook_url) }
  let(:web_uri)     { "file:/__web__?vfs=web&mode=ro&immutable=1&web_url=#{encoded_url}" }

  it 'loads and queries remote DB via sqlite3 gem' do
    begin
      require 'sqlite3'
    rescue LoadError
      skip 'sqlite3 gem not available'
    end
    db = SQLite3::Database.new(':memory:')
    SQLiteWebVFS::Loader.load(db)
    db.execute('ATTACH DATABASE ? AS remote', [web_uri])
    count = db.get_first_value('SELECT COUNT(*) FROM remote.Album')
    expect(count).to be_a(Integer)
  ensure
    db&.close
  end

  it 'loads and queries remote DB via sqlite3-ffi gem' do
    begin
      begin
        require 'sqlite3-ffi'
      rescue LoadError
        require 'sqlite3/ffi'
      end
    rescue LoadError
      skip 'sqlite3-ffi gem not available'
    end
    db = SQLite3::Database.new(':memory:')
    SQLiteWebVFS::Loader.load(db)
    db.execute('ATTACH DATABASE ? AS remote', [web_uri])
    count = db.execute('SELECT COUNT(*) FROM remote.Album').first.first
    expect(count).to be_a(Integer)
  ensure
    db&.close
  end
end

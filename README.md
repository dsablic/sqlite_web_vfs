# sqlite_web_vfs (Ruby gem)

[![CI](https://github.com/dsablic/sqlite_web_vfs/actions/workflows/ci.yml/badge.svg)](https://github.com/dsablic/sqlite_web_vfs/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/sqlite_web_vfs.svg)](https://badge.fury.io/rb/sqlite_web_vfs)
[![License](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE-3RD-PARTY.md)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.2-red.svg)](https://www.ruby-lang.org/)

This gem builds and loads the HTTP VFS from mlin/sqlite_web_vfs as a Ruby native extension (no CMake), and exposes a small loader helper to use it from both `sqlite3` and `sqlite3-ffi`.

Note: This gem includes code from mlin/sqlite_web_vfs, used under its original license.

## Features
- Wraps upstream C/C++ sources without modification (vendored in `ext/sqlite_web_vfs/upstream/`).
- Builds with `mkmf` and auto-detects SQLite via `pkg-config` or flags.
- macOS (Homebrew) and Amazon Linux 2023 supported.
- Optional, opt-in bundled SQLite amalgamation: `WEBVFS_FORCE_BUNDLED=1`.
- Loader works with both `sqlite3` and `sqlite3-ffi`.

## Install
- macOS (Homebrew): `brew install sqlite curl`
- Amazon Linux 2023: `sudo dnf install sqlite-devel libcurl-devel`

Then:

```
gem build sqlite_web_vfs.gemspec
gem install ./sqlite_web_vfs-*.gem
```

If SQLite isn’t found, you can point to it:

```
gem install sqlite_web_vfs -- --with-sqlite3-dir=/usr/local/opt/sqlite
```

Advanced option: bundle SQLite amalgamation inside the extension (may not interoperate with other SQLite users in the same process):

```
WEBVFS_FORCE_BUNDLED=1 gem install sqlite_web_vfs
```

## Security
Loading extensions can execute arbitrary native code. Only load trusted extensions from trusted locations and review your supply chain.

## Runtime API examples

### 1. Usage with `sqlite3`

```ruby
require 'sqlite3'
require 'sqlite_web_vfs'
require 'uri'

chinook_url = "https://github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite.sqlite"
encoded_url = URI.encode_www_form_component(chinook_url)
web_uri = "file:/__web__?vfs=web&mode=ro&immutable=1&web_url=#{encoded_url}"

db = SQLite3::Database.new(':memory:')
SQLiteWebVFS::Loader.load(db)
puts "HTTP VFS extension loaded."

db.execute("ATTACH DATABASE ? AS remote", [web_uri])
puts "Remote database attached as 'remote'."

album_count = db.get_first_value("SELECT COUNT(*) FROM remote.Album")
puts "Found #{album_count} albums in the remote Chinook database."
```

### 2. Usage with `sqlite3-ffi`

```ruby
require 'sqlite3-ffi'
require 'sqlite_web_vfs'
require 'uri'

chinook_url = "https://github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite.sqlite"
encoded_url = URI.encode_www_form_component(chinook_url)
web_uri = "file:/__web__?vfs=web&mode=ro&immutable=1&web_url=#{encoded_url}"

db = SQLite3::Database.new(':memory:')
SQLiteWebVFS::Loader.load(db)
puts "HTTP VFS extension loaded into FFI driver."

db.execute("ATTACH DATABASE ? AS remote", [web_uri])
puts "Remote database attached as 'remote'."

album_count = db.execute("SELECT COUNT(*) FROM remote.Album").first.first
puts "Found #{album_count} albums in the remote Chinook database."
```

### 3. Usage with SQLite CLI

**Note**: Extension loading requires SQLite to be compiled with extension support. Many system SQLite builds disable this for security (compiled with `OMIT_LOAD_EXTENSION`). If `.load` is unavailable, use the Ruby examples above instead.

For SQLite builds with extension support (use Homebrew's sqlite3 on macOS):

```bash
# macOS: Use Homebrew's sqlite3 which supports extensions
/opt/homebrew/bin/sqlite3 -cmd ".load $(ruby -r sqlite_web_vfs -e 'puts SQLiteWebVFS::Loader.built_extension_path')" -cmd "ATTACH DATABASE 'file:/__web__?vfs=web&mode=ro&immutable=1&web_url=https%3A//github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite.sqlite' AS remote;" ":memory:"

# Or with PATH updated to use Homebrew's sqlite3:
sqlite3 -cmd ".load $(ruby -r sqlite_web_vfs -e 'puts SQLiteWebVFS::Loader.built_extension_path')" -cmd "ATTACH DATABASE 'file:/__web__?vfs=web&mode=ro&immutable=1&web_url=https%3A//github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite.sqlite' AS remote;" ":memory:"
```

Then query the remote database:
```sql
SELECT COUNT(*) FROM remote.Album;
```

To check if your SQLite supports extensions:
```bash
sqlite3 ":memory:" "PRAGMA compile_options;" | grep -i load
```
If you see `OMIT_LOAD_EXTENSION`, use the Ruby API instead.

## Development
- Build: `gem build` then install the gem.
- Tests: `bundle exec rspec` (CI runs on Amazon Linux 2023 and macOS).

## License
- Vendored C/C++ from `mlin/sqlite_web_vfs`. See `LICENSE-3RD-PARTY.md`.
- This gem includes code from `mlin/sqlite_web_vfs`, used under its original license.


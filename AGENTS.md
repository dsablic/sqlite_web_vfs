# AGENTS.md — AI CLI instructions (concise)

**Purpose (one line)**
Generate a Ruby (MRI) gem that builds a loadable SQLite extension implementing the HTTP VFS from `mlin/sqlite_web_vfs` and exposes helpers to load/use it from the `sqlite3` and `sqlite3-ffi` gems. Upstream uses CMake — this gem must **not**; use `mkmf` and work on macOS and Amazon Linux 2023.

-----

## Licensing & Attribution

  - Vendored C/C++ sources from [mlin/sqlite\_web\_vfs](https://github.com/mlin/sqlite_web_vfs).
  - Retain original copyright headers and license notices.
  - Include a `LICENSE-3RD-PARTY.md` in the gem that reproduces the upstream license text.
  - Add a note in `README.md` and gemspec metadata: *“This gem includes code from `mlin/sqlite_web_vfs`, used under its original license.”*

-----

## Top-level rules (required)

1.  **Core Implementation**: The gem **must** be a wrapper around the original C/C++ source code from `mlin/sqlite_web_vfs`. The core functionality of fetching database pages via HTTP `Range` requests must be preserved exactly as in the upstream project. Do not re-implement the VFS logic in Ruby.
2.  **No CMake**: Implement build with `mkmf` (`extconf.rb`, `dir_config`, `have_header`, `have_library`, etc.).
3.  **Auto-detect sqlite3**: Prefer `pkg-config`; fall back to command-line flags (`--with-sqlite3-dir`, etc.) and environment variables.
4.  **Platform support**: Homebrew paths (macOS) and Amazon Linux 2023 (dnf-installed sqlite).
5.  **Bundled fallback (opt-in)**: `WEBVFS_FORCE_BUNDLED=1` triggers a build using a bundled sqlite amalgamation; otherwise, fail with clear installation instructions for the system dependency.
6.  **Expose runtime helpers**: Provide a simple loader module, `SQLiteWebVFS::Loader`, with methods like `built_extension_path`, `load(database_connection)`, etc., to abstract away loading logic for both `sqlite3` and `sqlite3-ffi`. Document security implications of enabling extension loading.

-----

## Files to generate (minimal)

  - `ext/sqlite_web_vfs/extconf.rb` (mkmf detection + makefile generation)
  - `ext/sqlite_web_vfs/shim.c` (C shim for the `Init_sqlite_web_vfs` function, which calls the upstream VFS registration)
  - `ext/sqlite_web_vfs/upstream/` (Vendored C/C++ source files and license from `mlin/sqlite_web_vfs`)
  - `lib/sqlite_web_vfs.rb` (Primary gem file, requires the loader)
  - `lib/sqlite_web_vfs/loader.rb` (Contains the `SQLiteWebVFS::Loader` module with all helper methods)
  - `README.md`, `sqlite_web_vfs.gemspec`, `LICENSE-3RD-PARTY.md`
  - `examples/` (Separate, clear usage examples for `sqlite3` and `sqlite3-ffi`)
  - `spec/integration/` (Integration tests using the Chinook DB)
  - CI workflows + Dockerfile (For testing on Amazon Linux 2023, using the official `amazonlinux:2023` Docker image)

-----

## extconf.rb checklist

  - `require 'mkmf'`, call `dir_config('sqlite3')`.
  - Detection order: `pkg-config` → command-line flags/env vars → `have_header`/`have_library`.
  - Set `$CFLAGS`/`$LDFLAGS` accordingly, then `create_makefile('sqlite_web_vfs/sqlite_web_vfs')`. This places the final shared object inside a subdirectory to avoid naming conflicts.
  - On failure: print explicit `gem install` examples for macOS (`brew install sqlite`) and Amazon Linux (`dnf install sqlite-devel`).
  - If `WEBVFS_FORCE_BUNDLED=1`, download the sqlite amalgamation and build against it, issuing a warning during installation.

-----

## Build artifact & Init function

  - Build a shared object (`sqlite_web_vfs.so` or `.bundle`) exposing `Init_sqlite_web_vfs()`.
  - Inside the `Init_sqlite_web_vfs` C function, call `sqlite3_auto_extension` with the entry point for the HTTP VFS. This ensures the VFS is available on any connection.

-----

## Minimal acceptance criteria

  - `gem build` and `gem install` work correctly on macOS (Apple Silicon/Intel) and Amazon Linux 2023.
  - The extension loads and functions correctly when used with both the `sqlite3` and `sqlite3-ffi` gems.
  - Integration tests against a remote Chinook DB succeed (e.g., from `https://github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite.sqlite`).
  - The scripts in the `examples/` directory (reflecting the Runtime API examples) **must** run successfully without errors and produce the expected output.

-----

## Runtime API examples

### 1\. Usage with `sqlite3` gem

This example demonstrates how to use the loader with the standard `sqlite3` gem. The loader helper handles finding the extension path and loading it into the database connection.

```ruby
require 'sqlite3'
require 'sqlite_web_vfs'
require 'uri'

# 1. Get the URL for the remote Chinook database
chinook_url = "https://github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite.sqlite"
encoded_url = URI.encode_www_form_component(chinook_url)

# 2. Construct the special URI that tells SQLite to use the 'web' VFS
# This URI is intercepted by the loaded C extension.
web_uri = "file:/__web__?vfs=web&mode=ro&immutable=1&web_url=#{encoded_url}"

# 3. Create a standard SQLite3 database instance
# Note: We are NOT using a custom Database class. This is the official gem.
db = SQLite3::Database.new(':memory:') # Open a temporary in-memory DB to load the extension

# 4. Load the VFS extension using the provided helper
SQLiteWebVFS::Loader.load(db)
puts "✅ HTTP VFS extension loaded."

# 5. Now, attach the remote database using the special URI
db.execute("ATTACH DATABASE ? AS remote", [web_uri])
puts "✅ Remote database attached as 'remote'."

# 6. Query the remote database through the attachment
album_count = db.get_first_value("SELECT COUNT(*) FROM remote.Album")
puts "💿 Found #{album_count} albums in the remote Chinook database."

db.close
```

### 2\. Usage with `sqlite3-ffi` gem

This example shows the same operation but using the `sqlite3-ffi` gem, which is common in JRuby environments or as a dependency of other gems like `sequel`.

```ruby
require 'sqlite3-ffi'
require 'sqlite_web_vfs'
require 'uri'

# The remote database URL and the special VFS URI are identical
chinook_url = "https://github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite.sqlite"
encoded_url = URI.encode_www_form_component(chinook_url)
web_uri = "file:/__web__?vfs=web&mode=ro&immutable=1&web_url=#{encoded_url}"

# 1. Create a database instance using the FFI gem
db = SQLite3::Database.new(':memory:')

# 2. Use the same loader helper. It will detect the FFI driver and use the correct API.
SQLiteWebVFS::Loader.load(db)
puts "✅ HTTP VFS extension loaded into FFI driver."

# 3. Attach and query the remote database
db.execute("ATTACH DATABASE ? AS remote", [web_uri])
puts "✅ Remote database attached as 'remote'."

album_count = db.execute("SELECT COUNT(*) FROM remote.Album").first.first
puts "💿 Found #{album_count} albums in the remote Chinook database."

db.close
```
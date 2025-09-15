#!/usr/bin/env ruby
# frozen_string_literal: true

require 'mkmf'
require 'fileutils'
require 'shellwords'
require 'net/http'
require 'uri'
# NOTE: mkmf will compile all .c/.cc files in this directory.

# Build settings
dir_config('sqlite3')

def darwin?
  (/darwin/ =~ RUBY_PLATFORM) != nil
end

def linux?
  (/linux/ =~ RUBY_PLATFORM) != nil
end

# Allow overriding via env or flags
sqlite_prefix = with_config('sqlite3-dir') || ENV.fetch('SQLITE3_DIR', nil)
if sqlite_prefix
  inc = File.join(sqlite_prefix, 'include')
  lib = File.join(sqlite_prefix, 'lib')
  dir_config('sqlite3', inc, lib)
  ENV['PKG_CONFIG_PATH'] = [File.join(lib, 'pkgconfig'), ENV.fetch('PKG_CONFIG_PATH', nil)].compact.join(':')
end

# HTTP implementation uses lazy-loaded libcurl when HTTP_LAZYCURL is defined.
# This avoids requiring libcurl at link time; on Linux we still need -ldl.
# Set required flags via mkmf CONFIG instead of globals
CONFIG['CPPFLAGS'] = [CONFIG['CPPFLAGS'], '-DHTTP_LAZYCURL'].compact.join(' ')
CONFIG['CXXFLAGS'] = [CONFIG['CXXFLAGS'], '-std=c++17', '-O2', '-DHTTP_LAZYCURL'].compact.join(' ')

have_library('dl') if linux?
have_library('pthread') if linux?

bundled = ENV['WEBVFS_FORCE_BUNDLED'] == '1'

if bundled
  warn "\n==> WEBVFS_FORCE_BUNDLED=1 set: building against bundled SQLite amalgamation.\n    " \
       'This is for advanced users and may not interoperate with other SQLite users in-process.'
  # Download the amalgamation
  require 'tmpdir'
  require 'zlib'
  require 'rubygems/package'

  amalgamation_version = ENV['SQLITE_AMALGAMATION_VERSION'] || '3460000' # 3.46.0
  base = "sqlite-amalgamation-#{amalgamation_version}"
  url  = "https://www.sqlite.org/2024/#{base}.zip"
  dest_dir = File.expand_path('sqlite-amalgamation', __dir__)
  FileUtils.mkdir_p(dest_dir)
  zip_path = File.join(dest_dir, "#{base}.zip")
  begin
    uri = URI.parse(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(Net::HTTP::Get.new(uri)) do |response|
        abort "Failed to download SQLite amalgamation from #{url}: #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)
        File.open(zip_path, 'wb') do |file|
          response.read_body { |chunk| file.write(chunk) }
        end
      end
    end
    # unzip minimal without external tools
    require 'zip'
  rescue LoadError
    # Fallback: try system unzip
  end
  if system('ruby', '-e', 'require "zip"; puts "ok"', out: File::NULL, err: File::NULL)
    require 'zip'
    Zip::File.open(zip_path) do |zip|
      %w[sqlite3.c sqlite3.h sqlite3ext.h].each do |f|
        e = zip.find_entry("#{base}/#{f}")
        File.write(File.join(dest_dir, f), e.get_input_stream.read)
      end
    end
  else
    abort "Failed to extract SQLite amalgamation from #{zip_path}. Install 'rubyzip' or 'unzip'." unless system("unzip -o #{Shellwords.escape(zip_path)} -d #{Shellwords.escape(dest_dir)}")
    %w[sqlite3.c sqlite3.h sqlite3ext.h].each do |f|
      src = File.join(dest_dir, base, f)
      FileUtils.cp(src, File.join(dest_dir, f))
    end
  end
  # NOTE: Generate a tiny wrapper C file so mkmf picks up the amalgamation without globals
  wrap_amalg = File.join(__dir__, '_wrap_sqlite3_amalgamation.c')
  File.write(wrap_amalg, "#include \"sqlite-amalgamation/sqlite3.c\"\n") unless File.exist?(wrap_amalg)
  # No need to link to system sqlite3 now
else
  # Try pkg-config after probing Homebrew keg
  begin
    brew_sqlite = `brew --prefix sqlite 2>/dev/null`.strip
    unless brew_sqlite.to_s.empty?
      ENV['PKG_CONFIG_PATH'] = [File.join(brew_sqlite, 'lib/pkgconfig'), ENV.fetch('PKG_CONFIG_PATH', nil)].compact.join(':')
      pkg_config('sqlite3') || true
    end
  rescue
  end
  # Try initial detection
  sqlite_ok = have_header('sqlite3.h') && have_library('sqlite3', 'sqlite3_libversion_number')
  # On macOS, also probe Homebrew keg paths if initial check failed or pkg-config lacked cflags
  if !sqlite_ok && darwin?
    begin
      brew_sqlite = `brew --prefix sqlite 2>/dev/null`.strip
      unless brew_sqlite.to_s.empty?
        dir_config('sqlite3', File.join(brew_sqlite, 'include'), File.join(brew_sqlite, 'lib'))
        ENV['PKG_CONFIG_PATH'] = [File.join(brew_sqlite, 'lib/pkgconfig'), ENV.fetch('PKG_CONFIG_PATH', nil)].compact.join(':')
        pkg_config('sqlite3') || true
        sqlite_ok = have_header('sqlite3.h') && have_library('sqlite3', 'sqlite3_libversion_number')
      end
    rescue
    end
  end
  unless sqlite_ok
    msg = <<~SQLITE_HELP

      Could not find SQLite3 development headers and library.

      Install SQLite and retry:
        - macOS (Homebrew):
            brew install sqlite
        - Amazon Linux 2023:
            sudo dnf install sqlite-devel

      Or specify a custom path:
        gem install sqlite_web_vfs -- --with-sqlite3-dir=/path/to/prefix

      To force building with a bundled SQLite amalgamation (advanced):
        WEBVFS_FORCE_BUNDLED=1 gem install sqlite_web_vfs
    SQLITE_HELP
    abort msg
  end
end

# Ensure libcurl headers are available for compilation (lazy loaded at runtime)
curl_ok = have_header('curl/curl.h')
if !curl_ok && darwin?
  begin
    brew_curl = `brew --prefix curl 2>/dev/null`.strip
    unless brew_curl.to_s.empty?
      dir_config('curl', File.join(brew_curl, 'include'), File.join(brew_curl, 'lib'))
      ENV['PKG_CONFIG_PATH'] = [File.join(brew_curl, 'lib/pkgconfig'), ENV.fetch('PKG_CONFIG_PATH', nil)].compact.join(':')
      pkg_config('libcurl') || true
      curl_ok = have_header('curl/curl.h')
    end
  rescue
  end
end
unless curl_ok
  msg = <<~CURL_HELP

    Could not find libcurl development headers (curl/curl.h).

    Install libcurl and retry:
      - macOS (Homebrew):
          brew install curl
      - Amazon Linux 2023:
          sudo dnf install libcurl-devel
  CURL_HELP
  abort msg
end

# On Linux, also link against libcurl to satisfy symbol resolution when loaders enforce RTLD_NOW.
have_library('curl', 'curl_easy_perform')

# Sources: C shim + vendored upstream C++ implementation
# NOTE: Generate a tiny wrapper to compile the upstream C++ file from this dir
wrap_web_vfs = File.join(__dir__, '_wrap_web_vfs.cc')
File.write(wrap_web_vfs, "#include \"upstream/web_vfs.cc\"\n") unless File.exist?(wrap_web_vfs)

# Ensure a C++ compiler is set and upstream headers are on include path
CONFIG['CXX'] ||= with_config('CXX', ENV['CXX'] || 'c++')
upstream_dir = File.expand_path('upstream', __dir__)
dir_config('upstream_headers', upstream_dir, nil)

create_makefile('sqlite_web_vfs/sqlite_web_vfs')

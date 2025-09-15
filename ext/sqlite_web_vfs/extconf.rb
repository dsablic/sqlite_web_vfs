require 'mkmf'
require 'fileutils'

extension_name = 'sqlite_web_vfs'
$srcs = []

# Build settings
dir_config('sqlite3')

def darwin?
  (/darwin/ =~ RUBY_PLATFORM) != nil
end

def linux?
  (/linux/ =~ RUBY_PLATFORM) != nil
end

# Allow overriding via env or flags
sqlite_prefix = with_config('sqlite3-dir') || ENV['SQLITE3_DIR']
if sqlite_prefix
  inc = File.join(sqlite_prefix, 'include')
  lib = File.join(sqlite_prefix, 'lib')
  $INCFLAGS << " -I#{inc}"
  $LDFLAGS  << " -L#{lib}"
  ENV['PKG_CONFIG_PATH'] = [File.join(lib, 'pkgconfig'), ENV['PKG_CONFIG_PATH']].compact.join(':')
end

# HTTP implementation uses lazy-loaded libcurl when HTTP_LAZYCURL is defined.
# This avoids requiring libcurl at link time; on Linux we still need -ldl.
$CPPFLAGS = [ENV['CPPFLAGS'], '-DHTTP_LAZYCURL'].compact.join(' ')
$CXXFLAGS = [ENV['CXXFLAGS'], '-std=c++11', '-O2'].compact.join(' ')

if linux?
  have_library('dl')
  $libs = append_library($libs, 'dl')
  $libs = append_library($libs, 'pthread')
end

bundled = ENV['WEBVFS_FORCE_BUNDLED'] == '1'

if bundled
  warn '\n==> WEBVFS_FORCE_BUNDLED=1 set: building against bundled SQLite amalgamation.\n' \
       '    This is for advanced users and may not interoperate with other SQLite users in-process.'
  # Download the amalgamation
  require 'open-uri'
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
    URI.open(url, 'rb') { |io| File.binwrite(zip_path, io.read) }
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
    unless system("unzip -o #{Shellwords.escape(zip_path)} -d #{Shellwords.escape(dest_dir)}")
      abort "Failed to extract SQLite amalgamation from #{zip_path}. Install 'rubyzip' or 'unzip'."
    end
    %w[sqlite3.c sqlite3.h sqlite3ext.h].each do |f|
      src = File.join(dest_dir, base, f)
      FileUtils.cp(src, File.join(dest_dir, f))
    end
  end
  $INCFLAGS << " -I#{dest_dir}"
  # Compile amalgamation directly into the extension to provide sqlite3 symbols
  $srcs << File.join('sqlite-amalgamation', 'sqlite3.c')
  # No need to link to system sqlite3 now
else
  # Try pkg-config after probing Homebrew keg
  begin
    brew_sqlite = `brew --prefix sqlite 2>/dev/null`.strip
    if !brew_sqlite.to_s.empty?
      ENV['PKG_CONFIG_PATH'] = [File.join(brew_sqlite, 'lib/pkgconfig'), ENV['PKG_CONFIG_PATH']].compact.join(':')
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
      if !brew_sqlite.to_s.empty?
        $INCFLAGS << " -I#{brew_sqlite}/include"
        $LDFLAGS  << " -L#{brew_sqlite}/lib"
        ENV['PKG_CONFIG_PATH'] = [File.join(brew_sqlite, 'lib/pkgconfig'), ENV['PKG_CONFIG_PATH']].compact.join(':')
        pkg_config('sqlite3') || true
        sqlite_ok = have_header('sqlite3.h') && have_library('sqlite3', 'sqlite3_libversion_number')
      end
    rescue
    end
  end
  unless sqlite_ok
    msg = <<~EOS
      
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
    EOS
    abort msg
  end
end

# Ensure libcurl headers are available for compilation (lazy loaded at runtime)
curl_ok = have_header('curl/curl.h')
if !curl_ok && darwin?
  begin
    brew_curl = `brew --prefix curl 2>/dev/null`.strip
    if !brew_curl.to_s.empty?
      $INCFLAGS << " -I#{brew_curl}/include"
      $LDFLAGS  << " -L#{brew_curl}/lib"
      ENV['PKG_CONFIG_PATH'] = [File.join(brew_curl, 'lib/pkgconfig'), ENV['PKG_CONFIG_PATH']].compact.join(':')
      pkg_config('libcurl') || true
      curl_ok = have_header('curl/curl.h')
    end
  rescue
  end
end
unless curl_ok
  msg = <<~EOS
    
    Could not find libcurl development headers (curl/curl.h).
    
    Install libcurl and retry:
      - macOS (Homebrew):
          brew install curl
      - Amazon Linux 2023:
          sudo dnf install libcurl-devel
  EOS
  abort msg
end

# Sources: C shim + vendored upstream C++ implementation
upstream_dir = File.expand_path('upstream', __dir__)
$INCFLAGS << " -I#{upstream_dir}"

$srcs += [
  File.join('shim.c'),
  File.join('upstream', 'web_vfs.cc')
]

# Let mkmf know we have C++ sources
CONFIG['CXX'] ||= with_config('CXX', ENV['CXX'] || 'c++')
$objs = $srcs.map { |s| s.sub(/\.[^.]+\z/, '.o') }

create_makefile('sqlite_web_vfs/sqlite_web_vfs')

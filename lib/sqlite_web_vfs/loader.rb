# frozen_string_literal: true

require 'rbconfig'

module SQLiteWebVFS
  module Loader
    module_function

    # Absolute path to the built native extension (.bundle/.so)
    def built_extension_path
      # The compiled extension is installed under this logical name by extconf.rb
      require_path = File.join('sqlite_web_vfs', 'sqlite_web_vfs')
      # Find the actual full path Ruby would use for this require
      $LOAD_PATH.each do |lp|
        Dir[File.join(lp, "#{require_path}.{so,bundle,dll}")].each do |p|
          return p if File.file?(p)
        end
        # Ruby might place it in a versioned directory under lp/sqlite_web_vfs
        Dir[File.join(lp, 'sqlite_web_vfs', 'sqlite_web_vfs.{so,bundle,dll}')].each do |p|
          return p if File.file?(p)
        end
      end
      nil
    end

    # Load the HTTP VFS into the process (auto-applied to connections).
    # This only requires the compiled extension; it registers itself via sqlite3_auto_extension.
    # Security note: Loading extensions can execute native code. Only load trusted code.
    def load(db = nil)
      begin
        require 'sqlite_web_vfs/sqlite_web_vfs'
      rescue LoadError
        raise_load_error(<<~MSG)
          Could not locate the sqlite_web_vfs native extension. Ensure the gem built correctly.
          - macOS:   brew install sqlite curl
          - Amazon Linux 2023: sudo dnf install sqlite-devel libcurl-devel
          If SQLite is installed but detection failed, rebuild with:
            gem uninstall sqlite_web_vfs && gem install sqlite_web_vfs -- --with-sqlite3-dir=/path/to/prefix
          To force building with a bundled SQLite amalgamation (advanced):
            WEBVFS_FORCE_BUNDLED=1 gem install sqlite_web_vfs
        MSG
      end

      # Determine loaded extension path, if any
      dlex = %w[so bundle dll]
      so = $LOADED_FEATURES.find do |f|
        dlex.any? { |ext| f.end_with?("/sqlite_web_vfs/sqlite_web_vfs.#{ext}") }
      end

      # Ensure the current connection loads the extension too (auto-extension affects future opens)
      if db
        db.enable_load_extension(true) if db.respond_to?(:enable_load_extension)
        if db.respond_to?(:load_extension)
          db.load_extension(so) if so
        elsif db.respond_to?(:api) && db.api.respond_to?(:load_extension)
          if so
            rc = db.api.load_extension(db.handle, so, nil, nil)
            raise_load_error("sqlite3-ffi load_extension failed with code #{rc}") unless rc.zero?
          end
        end
      end
      so
    end

    def raise_load_error(msg)
      raise LoadError, "SQLiteWebVFS::Loader: #{msg}"
    end
  end
end

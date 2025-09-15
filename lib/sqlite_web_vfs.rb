# frozen_string_literal: true

require_relative 'sqlite_web_vfs/loader'

module SQLiteWebVFS
  # Requiring the compiled extension ensures the VFS registers via sqlite3_auto_extension.
  begin
    require 'sqlite_web_vfs/sqlite_web_vfs'
  rescue LoadError
    # The loader will surface clearer installation instructions when used.
  end
end

# frozen_string_literal: true

version = File.read(File.expand_path('VERSION', __dir__)).strip

Gem::Specification.new do |spec|
  spec.name = 'sqlite_web_vfs'
  spec.version = version
  spec.summary = 'Loadable SQLite HTTP VFS (Ruby loader)'
  spec.description = 'Builds and loads the HTTP VFS from mlin/sqlite_web_vfs for SQLite, enabling remote DB access over HTTP(S) via Range requests.'
  spec.email = 'denis.sablic@gmail.com'
  spec.author = 'Denis Sablic'
  spec.homepage = 'https://github.com/dsablic/sqlite_web_vfs'
  spec.required_ruby_version = '>= 3.2.0'
  spec.license = 'BSD-3-Clause' # Upstream BSD-3-Clause; this gem code can be MIT/BSD

  spec.files = Dir.glob('{lib,ext,examples,spec}/**/*', File::FNM_DOTMATCH).select { |f| File.file?(f) } + [
    'README.md',
    'LICENSE-3RD-PARTY.md'
  ]
  spec.require_paths = ['lib']
  spec.extensions = ['ext/sqlite_web_vfs/extconf.rb']

  spec.metadata = {
    'rubygems_mfa_required' => 'true',
    'source_code_uri' => 'https://github.com/dsablic/sqlite_web_vfs',
    'bug_tracker_uri' => 'https://github.com/dsablic/sqlite_web_vfs/issues'
  }
end

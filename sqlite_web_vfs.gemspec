# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "sqlite_web_vfs"
  spec.version       = "0.1.0"
  spec.summary       = "Loadable SQLite HTTP VFS (Ruby loader)"
  spec.description   = "Builds and loads the HTTP VFS from mlin/sqlite_web_vfs for SQLite, enabling remote DB access over HTTP(S) via Range requests."
  spec.authors       = ["Your Name"]
  spec.email         = ["you@example.com"]

  spec.homepage      = "https://github.com/your-org/sqlite_web_vfs-ruby"
  spec.license       = "BSD-3-Clause" # Upstream BSD-3-Clause; this gem code can be MIT/BSD

  spec.files = Dir.glob("{lib,ext,examples,spec}/**/*", File::FNM_DOTMATCH).select { |f| File.file?(f) } + [
    "README.md",
    "LICENSE-3RD-PARTY.md"
  ]
  spec.require_paths = ["lib"]
  spec.extensions    = ["ext/sqlite_web_vfs/extconf.rb"]

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => spec.homepage,
    "allowed_push_host" => "https://rubygems.org",
    "rubygems_mfa_required" => "true",
    "licenses" => "BSD-3-Clause",
    "upstream_notice" => "This gem includes code from mlin/sqlite_web_vfs, used under its original license."
  }

  spec.required_ruby_version = ">= 2.7"
end

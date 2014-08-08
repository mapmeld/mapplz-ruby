# Encoding: utf-8
$LOAD_PATH.push File.expand_path('../lib', __FILE__)

Gem::Specification.new do |s|
  s.name = 'mapplz'
  s.version = '0.1.7'
  s.platform = Gem::Platform::RUBY
  s.authors = ['Nick Doiron']
  s.email = ['ndoiron@mapmeld.com']
  s.license = 'BSD'
  s.homepage = 'https://github.com/mapmeld/mapplz-ruby'
  s.summary = 'Quick and easy mapping with MapPLZ'
  s.description = 'Quick and easy mapping with MapPLZ'

  s.files = Dir['lib/**/*'] + Dir['app/**/*'] + ['README.md']
  s.require_paths = ['lib']

  s.add_dependency 'sql_parser'
  s.add_dependency 'geokdtree'
  s.add_dependency 'leaflet-rails'
  s.add_dependency 'sqlite3'
  s.add_dependency 'pg'
  s.add_dependency 'mongo'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'simplecov-rcov'
  s.add_development_dependency 'actionpack', '>= 3.2.0'
  s.add_development_dependency 'activesupport', '>= 3.2.0'
  s.add_development_dependency 'activemodel', '>= 3.2.0'
  s.add_development_dependency 'railties', '>= 3.2.0'
end

source 'https://rubygems.org'

ruby '2.0.0', engine: 'jruby', engine_version: '1.7.15'

gemspec

gem 'rosette-core', github: 'rosette-proj/rosette-core', branch: 'push_by_branch'

group :development, :test do
  gem 'activemodel'
  gem 'expert', '~> 1.0.0'
  gem 'pry', '~> 0.9.0'
  gem 'pry-nav'
  gem 'rake'
end

group :test do
  gem 'codeclimate-test-reporter', require: nil
  gem 'factory_girl', '~> 4.4.0'
  gem 'rosette-datastore-memory', github: 'rosette-proj/rosette-datastore-memory'
  gem 'rosette-test-helpers', github: 'rosette-proj/rosette-test-helpers'
  gem 'rspec'
end

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.0'

# Core
gem 'rails', '~> 7.1.0'
gem 'puma', '~> 6.0'
gem 'bootsnap', '>= 1.4.4', require: false

# Database
gem 'pg', '~> 1.5'

# API
gem 'rack-cors'
gem 'jbuilder', '~> 2.11'
gem 'active_model_serializers'

# Blockchain
gem 'eth', '~> 0.5.0'
gem 'keccak', '~> 1.3'

# HTTP Client
gem 'httparty'
gem 'faraday'

# Background Jobs
gem 'sidekiq', '~> 7.0'
gem 'sidekiq-scheduler'

# Utilities
gem 'dotenv-rails'
gem 'merkle_tree', '~> 0.1.0'
gem 'openssl'

# Development
group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'rspec-rails'
  gem 'factory_bot_rails'
end

group :development do
  gem 'web-console', '>= 4.1.0'
  gem 'listen', '~> 3.3'
  gem 'spring'
end


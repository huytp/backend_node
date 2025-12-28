require 'sidekiq'
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
end

# Load schedule from YAML file
schedule_file = Rails.root.join('config', 'sidekiq.yml')
if File.exist?(schedule_file)
  Sidekiq.schedule = YAML.load_file(schedule_file)['schedule'] || {}
end


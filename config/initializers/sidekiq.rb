require 'sidekiq'
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }

  # Load schedule from YAML file on startup
  config.on(:startup) do
    schedule_file = Rails.root.join('config', 'sidekiq.yml')
    if File.exist?(schedule_file)
      schedule = YAML.safe_load(File.read(schedule_file), permitted_classes: [Symbol], aliases: true) || {}
      Sidekiq.schedule = schedule['schedule'] || {}
      Sidekiq::Scheduler.reload_schedule!
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
end


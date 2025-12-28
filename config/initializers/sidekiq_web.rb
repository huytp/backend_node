# Sidekiq Web UI Configuration
# Access at: http://localhost:3000/sidekiq

require 'sidekiq/web'
require 'sidekiq-scheduler/web'

# Optional: Add authentication for production
# Uncomment and customize for production use
#
# Sidekiq::Web.use Rack::Auth::Basic do |username, password|
#   ActiveSupport::SecurityUtils.secure_compare(
#     ::Digest::SHA256.hexdigest(username),
#     ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_USERNAME'] || 'admin')
#   ) &
#   ActiveSupport::SecurityUtils.secure_compare(
#     ::Digest::SHA256.hexdigest(password),
#     ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_PASSWORD'] || 'password')
#   )
# end





Rails.application.routes.draw do
  # Sidekiq Web UI
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'

  # API Gateway routes

  # Auth endpoints
  namespace :auth do
    post 'register', to: 'auth#register'
    post 'login', to: 'auth#login'
    get 'me', to: 'auth#me'
    post 'logout', to: 'auth#logout'
  end

  # Node endpoints
  namespace :nodes do
    post 'heartbeat', to: 'nodes#heartbeat'
    get 'status/:address', to: 'nodes#status'
    get 'status', to: 'nodes#index'
    post 'traffic', to: 'traffic#create'
    post 'traffic/batch', to: 'traffic#batch_create'
  end

  # VPN endpoints
  namespace :vpn do
    post 'connect', to: 'connections#connect'
    post 'disconnect', to: 'connections#disconnect'
    get 'status/:connection_id', to: 'connections#status'
    get 'connections/active', to: 'connections#active'
  end

  # Reward endpoints
  namespace :rewards do
    get 'epoch/:id', to: 'rewards#epoch'
    get 'proof', to: 'rewards#proof'
    get 'epochs', to: 'rewards#epochs'
    get 'current_epoch', to: 'rewards#current_epoch'
    get 'verify/:epoch_id', to: 'rewards#verify'
    get 'eligibility/:traffic_record_id', to: 'rewards#check_eligibility'
  end

  # Health check
  get 'health', to: 'health#check'
  post 'health/upload_test', to: 'health#upload_test'
end


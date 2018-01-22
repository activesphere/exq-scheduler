# This file is used by Rack-based servers to start the application.

require_relative 'config/environment'
require 'sidekiq/web'
require 'sidekiq-scheduler/web'

REDIS_URL = 'redis://127.0.0.1:6379/0'

# If your client is single-threaded, we just need a single connection in our Redis connection pool
Sidekiq.configure_client do |config|
    config.redis = Sidekiq::RedisConnection.create(:url => REDIS_URL, :namespace => 'exq', :size => 1)
end

# Sidekiq server is multi-threaded so our Redis connection pool size defaults to concurrency (-c)
Sidekiq.configure_server do |config|
    config.redis = Sidekiq::RedisConnection.create(:url => REDIS_URL, :namespace => 'exq')
end

run Rails.application
run Sidekiq::Web

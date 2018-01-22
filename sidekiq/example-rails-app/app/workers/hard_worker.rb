REDIS_URL = 'redis://127.0.0.1:6379/0'

require 'sidekiq-scheduler'

# If your client is single-threaded, we just need a single connection in our Redis connection pool
Sidekiq.configure_client do |config|
  config.redis = Sidekiq::RedisConnection.create(:url => REDIS_URL, :namespace => 'exq', :size => 1)
end

# Sidekiq server is multi-threaded so our Redis connection pool size defaults to concurrency (-c)
Sidekiq.configure_server do |config|
  config.redis = Sidekiq::RedisConnection.create(:url => REDIS_URL, :namespace => 'exq')
end

class HardWorker
  include Sidekiq::Worker

  def perform(how_hard="super hard", how_long=1)
    sleep how_long
    puts "Workin' #{how_hard} for #{how_long}s."
  end
end

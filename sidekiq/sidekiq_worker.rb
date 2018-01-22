require 'sidekiq-scheduler'

REDIS_URL = 'redis://127.0.0.1:6379/1'

# If your client is single-threaded, we just need a single connection in our Redis connection pool
Sidekiq.configure_client do |config|
  config.redis = { :namespace => 'exq', :size => 1, url: REDIS_URL }
end

# Sidekiq server is multi-threaded so our Redis connection pool size defaults to concurrency (-c)
Sidekiq.configure_server do |config|
  config.redis = { :namespace => 'exq', url: REDIS_URL }
end

# Start up sidekiq via
# ./bin/sidekiq -r ./sidekiq.rb
# and then you can open up an IRB session like so:
# irb -r ./sidekiq.rb
# where you can then say
# SidekiqWorker.perform_async "like a dog", 3
# NOTE: This is as per an example from the sidekiq's source repo -
# https://github.com/mperham/sidekiq/blob/master/examples/por.rb
#
class SidekiqWorker
  include Sidekiq::Worker

  def perform(how_hard="super hard", how_long=1)
    sleep how_long
    puts "Workin' #{how_hard} for #{how_long}s."
  end
end

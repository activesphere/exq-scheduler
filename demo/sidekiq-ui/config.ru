require 'sidekiq/web'
require 'sidekiq-scheduler/web'

url = 'redis://localhost:6379'
namespace = 'exq'

Sidekiq.configure_client do |config|
  config.redis = {url: url, namespace: 'exq'}
end

Sidekiq.configure_server do |config|
  config.redis = {url: url, namespace: 'exq'}
end

run Sidekiq::Web

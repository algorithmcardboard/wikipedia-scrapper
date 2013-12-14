$redis = Redis.new(:host => 'localhost', :port => 6379)

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
      $redis.client.disconnect
      $redis = Redis.new(:host => 'localhost', :port => 6379)
      Rails.logger.info "Reconnecting to redis"
    else
      # We're in conservative spawning mode. We don't need to do anything.
    end
  end
end

port 6555
daemonize yes
pidfile "/tmp/resquex-redis-sentinel.pid"
sentinel monitor exq 127.0.0.1 6379 1

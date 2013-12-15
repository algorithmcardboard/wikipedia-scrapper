redis-cli KEYS "WIKI*" | xargs redis-cli DEL
redis-cli keys "*"

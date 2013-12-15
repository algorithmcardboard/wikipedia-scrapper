redis-cli KEYS "TEXT:*" | xargs redis-cli DEL
redis-cli KEYS "YEAR:*" | xargs redis-cli DEL
redis-cli KEYS "LENGTH:*" | xargs redis-cli DEL
redis-cli del wikiparser
redis-cli keys "*"

module RedisService
  
  REDIS_TIMEOUT = 1200
  REDIS_OUTPUT_QUEUE = "WIKIPARSER:OUTPUT"
  PARSER_LOCK_KEY = "WIKIPARSER:LOCK"
  REDIS_STATUS_KEY = "WIKIPARSER:STATUS"

  def getYearKey(category_id, year, month, day)
    "WIKIPARSER:YEAR:#{category_id}:#{day}-#{month}-#{year}"
  end

  def getTextKey(category_id, word, month, day)
    "WIKIPARSER:TEXT:#{category_id}:#{day}-#{month}-#{word}"
  end

  def getKeyForLength(event_id)
    "WIKIPARSER:LENGTH:#{event_id}"
  end

  def pushWordLengthForEvent(event_id, event_words_length)
    redis_length_key = getKeyForLength(event_id)
    Redis.current.redis.set(redis_length_key, event_words_length)
    Redis.current.expire(redis_length_key, REDIS_TIMEOUT)
  end

  def pushYearAndEventToInvertedIndex(category_id, month, day, year, event_id)
    redis_year_key = getYearKey(category_id, year, month, day);
    Redis.current.sadd(redis_year_key, event_id)
    Redis.current.expire(redis_year_key, REDIS_TIMEOUT)
  end

  def pushWordAndEventToInvertedIndex(category_id, month, day, word, event_id)
    redis_word_key = getTextKey(category_id, word, month, day);
    Redis.current.sadd(redis_word_key, event_id)
    Redis.current.expire(redis_word_key, REDIS_TIMEOUT)
  end

  def setProcessStatusInRedis(status)
    Redis.current.set(REDIS_STATUS_KEY,status)
  end

  def getProcessStatusInRedis()
    Redis.current.get(REDIS_STATUS_KEY)
  end

  def purgeAllRedisData
    Redis.current.del(Redis.current.keys("WIKIPARSER:*"))
  end
end

module RedisService
  
  REDIS_TIMEOUT = 1200

  def getYearKey(category_id, year, month, day)
    "YEAR:#{category_id}:#{day}-#{month}-#{year}"
  end

  def getTextKey(category_id, word, month, day)
    "TEXT:#{category_id}:#{day}-#{month}-#{word}"
  end

  def getKeyForLength(event_id)
    "LENGTH:#{event_id}"
  end
end

class EventController < ApplicationController
  include RedisService

  PARSER_LOCK_KEY = 'wikiparser'
    def index
    end

    def date
      month_date = params[:month_date] #not changing to any custom name.  Need not bother this one.
      threshold = params[:threshold].to_i

      threshold = 3 if(threshold.blank?)

      month, day = month_date.split("_").map{ |n| n.to_i}

      unless month >= 1 && month <= 12 && day >= 1 && Rails.application.config.days_in_month[month - 1] >= day
        logger.info "not a valid one"
        render json: {error:'not a valid month/date'}, status: :unprocessable_entity
        return
      end

      lock = $redis.setnx(PARSER_LOCK_KEY,params[:month_date])

      logger.info "Value of lock is #{lock}"

      unless(lock)
        render json: {error:'Another process under execution.  Try after some time'}, status: :unprocessable_entity
        return
      end

      $redis.expire(PARSER_LOCK_KEY,REDIS_TIMEOUT);
      getEventsAfterPopulatingInvertedIndex(month,day)


      WikipediaParser.perform_async(month,day, threshold)
      render json: {}
    end

  private
    def getEventsAfterPopulatingInvertedIndex(month,day)
      Event.where(["month = ? and day = ?",month, day]).each do |event|

        event_words = event.event.downcase.gsub(/[^\w\d ]/," ").split + event.name.downcase.gsub(/[^\w\d ]/," ").split - Rails.application.config.stop_words
        event_year = event.year
        event_category = event.category_id

        pushYearAndEventToInvertedIndex(event_category, month, day, event_year, event.id)

        event_words.each  do |word|
          pushWordAndEventToInvertedIndex(event_category, month, day, word, event.id)
        end
        
        pushWordLengthForEvent(event.id, event_words.length)
      end
    end

    def pushWordLengthForEvent(event_id, event_words_length)
      redis_length_key = getKeyForLength(event_id)
      $redis.set(redis_length_key, event_words_length)
      $redis.expire(redis_length_key, REDIS_TIMEOUT)
    end

    def pushYearAndEventToInvertedIndex(category_id, month, day, year, event_id)
      redis_year_key = getYearKey(category_id, year, month, day);
      $redis.sadd(redis_year_key, event_id)
      $redis.expire(redis_year_key, REDIS_TIMEOUT)
    end

    def pushWordAndEventToInvertedIndex(category_id, month, day, word, event_id)
      redis_word_key = getTextKey(category_id, word, month, day);
      $redis.sadd(redis_word_key, event_id)
      $redis.expire(redis_word_key, REDIS_TIMEOUT)
    end
end

class EventController < ApplicationController

  REDIS_TIMEOUT = 1200
  PARSER_LOCK_KEY = 'wikiparser'
    def index
    end

    def date
      month_date = params[:month_date] #not changing to any custom name.  Need not bother this one.

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

      Event.where(["month = ? and day = ?",month, day]).each do |event|

        event_words = event.event.downcase.gsub(/[^\w\d ]/," ").split - Rails.application.config.stop_words
        event_year = event.year

        pushYearAndEventToInvertedIndex(month, day, event_year, event.id)

        event_words.each  do |word|
          pushWordAndEventToInvertedIndex(month, day, word, event.id)
        end
      end

      WikipediaParser.perform_async(month,day)
      render json: {}
    end

  private
    def pushYearAndEventToInvertedIndex(month, day, year, event_id)
      redis_year_key = "YEAR:#{day}-#{month}-#{year}"
      $redis.sadd(redis_year_key, event_id)
      $redis.expire(redis_year_key, REDIS_TIMEOUT)
    end

    def pushWordAndEventToInvertedIndex(month, day, word, event_id)
      redis_word_key = "#{day}-#{month}-#{word}"
      $redis.sadd(redis_word_key, event_id)
      $redis.expire(redis_word_key, REDIS_TIMEOUT)
    end
end

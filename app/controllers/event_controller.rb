class EventController < ApplicationController
  include RedisService

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
      result = getEventsAfterPopulatingInvertedIndex(month,day)

      WikipediaParser.perform_async(month,day, threshold)
      render json: result 
    end

    def poll
      results = Array.new
      while(!(event = $redis.rpop(REDIS_OUTPUT_QUEUE)).blank?)
        event = JSON.parse(event)
        results << event
      end
      status = getProcessStatusInRedis()

      if(status == 'Done')
        purgeAllRedisData()
      end

      render json: {events:results, status: status}
    end

  private
    def getEventsAfterPopulatingInvertedIndex(month,day)
      category_eventId_event = Hash.new

      Event.select(:id, :category_id, :name, :event, :year).where(["month = ? and day = ?",month, day]).each do |event|
        if(category_eventId_event[event.category_id].blank?)
          category_eventId_event[event.category_id] = Hash.new
        end
        category_eventId_event[event.category_id][event.id] = event

        event_words = event.event.downcase.gsub(/[^\w\d ]/," ").split + event.name.downcase.gsub(/[^\w\d ]/," ").split - Rails.application.config.stop_words
        event_year = event.year
        event_category = event.category_id

        pushYearAndEventToInvertedIndex(event_category, month, day, event_year, event.id)
        pushWordLengthForEvent(event.id, event_words.length)
        event_words.each  do |word|
          pushWordAndEventToInvertedIndex(event_category, month, day, word, event.id)
        end
      end

      return category_eventId_event
    end
end

class EventController < ApplicationController
  include RedisService, WikiparserService

    def index
    end

    def addEvents
      missingEvents = params[:missingEvents]
      category_id = params[:category_id]
      day = params[:day]
      month = params[:month]

      if(missingEvents.blank? || category_id.blank? || day.blank? || month.blank?)
        render json: {}, status: :unprocessable_entity
        return
      end

      user_id = 0
      status = 3

      event_to_obj = Hash.new

      missingEvents.each do | wiki_event_text |
        year, name, event_text = getEventDetailsForPersisting(wiki_event_text,category_id.to_i)
        event_obj = Event.new({:name => name, :event=> event_text, :day=> day, :month=> month, :year=> year, :user_id=> user_id, :category_id => category_id, :status => status})
        next unless event_obj.valid?
        event_to_obj[wiki_event_text] = event_obj
      end

      event_to_obj.each do | wiki_text, event_obj | 
        node = Nokogiri::HTML::fragment(wiki_text)
        node.css("a").each do | anchor |
          next if(isDateAnchor(anchor['href']))

          event_obj.links << Link.find_or_create_by(:url => anchor['href'], :name => anchor.text)
        end
      end

      Event.transaction do 
        event_to_obj.values.each(&:save!)
      end

      render json: {}

    end

    def addLinks
      duplicateEvents = params[:duplicateEvents]


      eventLinks = Array.new

      duplicateEvents.each do |eventId_to_text|
        event_id = eventId_to_text[0]
        node_text = eventId_to_text[1]

        Nokogiri::HTML::fragment(node_text).css("a").each do |anchor|
          next if(isDateAnchor(anchor['href']))
          link = Link.find_or_create_by(:url => anchor['href'], :name => anchor.text.truncate(50))
          eventLinks << EventsLink.new({:event_id => event_id, :link_id => link.id})
        end
      end

      EventsLink.transaction do 
        eventLinks.each(&:insert_ignore)
      end

      render json: {}
    end

    def date
      month_date = params[:month_date] #not changing to any custom name.  Need not bother this one.

      threshold = 5

      month, day = month_date.split("_").map{ |n| n.to_i}

      unless month >= 1 && month <= 12 && day >= 1 && Rails.application.config.days_in_month[month - 1] >= day
        logger.info "not a valid one"
        render json: {error:'not a valid month/date'}, status: :unprocessable_entity
        return
      end

      lock = Redis.current.setnx(PARSER_LOCK_KEY,params[:month_date])

      logger.info "Value of lock is #{lock}"

      unless(lock)
        render json: {error:'Another process under execution.  Try after some time'}, status: :unprocessable_entity
        return
      end

      Redis.current.expire(PARSER_LOCK_KEY,REDIS_TIMEOUT);

      WikipediaParser.perform_async(month,day, threshold)

      result = getEventsAfterPopulatingInvertedIndex(month,day)
      setProcessStatusInRedis('DB done')

      render json: result 
    end

    def poll
      results = Array.new
      while(!(event = Redis.current.rpop(REDIS_OUTPUT_QUEUE)).blank?)
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

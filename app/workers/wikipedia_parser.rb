# encoding: UTF-8

require 'open-uri'
require 'set'

class WikipediaParser
  include Sidekiq::Worker, RedisService, WikiparserService, SimilarityService

  WIKIPEDIA_PREFIX = 'http://en.wikipedia.org';

  def perform(month, day, threshold)
    month_name = Rails.application.config.months_name[month - 1]

    wikipedia_url = WIKIPEDIA_PREFIX+"/wiki/#{month_name}_#{day}"
    logger.info wikipedia_url

    doc = Nokogiri::HTML(open(wikipedia_url))

    while(true)
      logger.info "sleeping for 0.75 seconds"
      sleep 0.75
      if(getProcessStatusInRedis() == 'DB done')
        break;
      end
    end

    duplicate_events = Hash.new
    @negative_event_id = 0 
    @editDistancePass = 0
    @editDistanceFail = 0
    @holidayCount = 0

    #I shouldn't have done this. crap code
    setProcessStatusInRedis('Fetching missing events')
    doc.css('.mw-headline').each do |headline_div|

      unless (Rails.application.config.allowed_wiki_headlines.has_key?(headline_div.text))
        logger.error "Unknown headline #{headline_div.text}from wikipedia.  Might be a unobserved case. Investigate." 
        next
      end

      unless( Rails.application.config.allowed_wiki_headlines[headline_div.text] )
        logger.info "skipping #{headline_div.text}. not in allowed list"
        next
      end

      duplicate_events.merge!(processEventsInPage(month, day, headline_div))
    end

    #process only for duplicates
    setProcessStatusInRedis('Finding duplicates')
    calculateEditDistanceAndPush(duplicate_events, threshold)
    setProcessStatusInRedis('Done')
    logger.info "holidayCount is #{@holidayCount}"
    logger.info "total events passing edit distance check #{@editDistancePass}. Failed ones #{@editDistanceFail}"
  end

  private

    def calculateEditDistanceAndPush(duplicate_events, threshold)
      return if(duplicate_events.blank?)
      ids = duplicate_events.keys
      Event.select(:id, :name, :event, :year, :category_id).where(["id in (?)",ids]).each do |event|
        duplicate_events[event.id.to_s].each do |wiki_text|

          wiki_node = Nokogiri::HTML::fragment(wiki_text)
          belongs_to = nil

          if(event.category_id.to_i == 39 || event.category_id.to_i == 36)
            event_text = "#{event.name} #{event.event}"
          else
            event_text = "#{event.year} #{event.name} #{event.event}"
          end

          if(editDistance("#{event.name} #{event.event}", wiki_node.text) < threshold)
            belongs_to = event.id
            @editDistancePass += 1
          else
            @editDistanceFail += 1
            logger.debug "doesn't meet threshold #{event.id} #{event.event}"
          end

          parseAndPushToRedisOutputQueue(event.year, wiki_node, belongs_to, event.category_id)
        end
      end
      logger.info "Total pass #{@editDistancePass}. Total fail #{@editDistanceFail}"
    end

    def getCommonEventsForHoliday(event_node, day, month)
      category_id = 39
      @holidayCount += 1
      event_text = event_node.text
      event_words = event_text.downcase.gsub(/[^\w\d ]/," ").split - Rails.application.config.stop_words

      common_events = Hash.new
      event_words.each do |word|
        cur_event = Hash[$redis.smembers(getTextKey(category_id, word, month, day) ).map{|elem| [elem,1]}]

        # This will help us calculate cosine similarity
        common_events.merge!(cur_event) {|key,val1,val2| val1+val2}
      end

      #remove all entries that doesn't meet a threshold
      common_events.select!{|event_id,count| isSimilar(count, event_words.length, $redis.get(getKeyForLength(event_id)).to_i)}
      common_events.update(common_events){|key, value| Set.new [event_node.to_s]}

      if(common_events.blank?)
        parseAndPushToRedisOutputQueue(0, event_node, nil, 39)
      end

      return common_events #returns common_events. this is captain obvious comment
    end

    def processEventsInPage(month, day, headline_div)

      possible_duplicate_events = Hash.new

      category_id = Rails.application.config.wiki_tih_mapping[headline_div.text]
      logger.info "known headline #{headline_div.text} with category_id #{category_id}"

      unpushed = pushed = 0

      #
      # The below code should ideally be done with composition instead of such shitty way of writing. I hate this code.
      #
      if(category_id.to_i == 39)
        next_elem = headline_div.parent.next_element
        while(next_elem.name != 'h2')
          next_elem.css("li:not(:has(ul))").each do |event_node|
            common_events = getCommonEventsForHoliday(event_node, day, month)
            possible_duplicate_events.merge!(common_events) {|key, val1, val2| val1.merge(val2)}
          end
          next_elem = next_elem.next_element
        end
        return possible_duplicate_events
      end

      headline_div.parent.next_element.css("li").each do |event_node|

        event_node.name = 'span'


        year, event_text = event_node.text.split("–", 2)

        #parse and get year and text.  Split text to array and remove stop words
        year_key = getYearKey(category_id, getYearValueInInt(year), month, day)
        events_on_year = $redis.smembers(year_key)

        #if no events for the year. There is no point in searching with words. Just push the text directly to the output stream
        if(events_on_year.blank? || (common_events = getCommonEvents(year_key, month, day, event_text, category_id)).blank?)
          parseAndPushToRedisOutputQueue(year, event_node, nil, category_id)
          pushed += 1
          next
        end

        unpushed += 1

        common_events.update(common_events){|key, value| Set.new [event_node.to_s]}

        possible_duplicate_events.merge!(common_events) {|key, val1, val2| val1.merge(val2)}

      end
      logger.info "#{pushed} pushed directly.  #{unpushed} yet to be processed"

      possible_duplicate_events
    end

    def getCommonEvents(year_key, month, day, event_text, category_id)
      event_words = event_text.downcase.gsub(/[^\w\d ]/," ").split - Rails.application.config.stop_words

      common_events = Hash.new

      event_words.each do |word|
        cur_event = Hash[$redis.sinter(year_key, getTextKey(category_id, word, month, day) ).map{|elem| [elem,1]}]
        #intersect cur_event and common_events and add the number of times we have seen a particular event 
        #.  This will help us calculate cosine similarity
        common_events.merge!(cur_event) {|key,val1,val2| val1+val2}
      end

      #remove all entries that doesn't meet a threshold
      common_events.select!{|event_id,count| isSimilar(count, event_words.length, $redis.get(getKeyForLength(event_id)).to_i)}

      common_events
    end

    def parseAndPushToRedisOutputQueue(year, event_node, belongs_to, category_id)

      @negative_event_id -= 1
      event_node.css("a").each do |anchor|
        anchor['href'] = WIKIPEDIA_PREFIX + anchor['href']
      end

      event_text = event_node.text

      output_text = event_text if(category_id.to_i == 39)
      output_text = event_text.split("–",2)[1] if(category_id.to_i != 39)

      if(output_text.blank?)
        logger.error "output_text blank for #{event_text}"
      end

      output =  {
        event_id: @negative_event_id,
        event: event_node.to_s,
        category_id: category_id,
        belongs_to: belongs_to,
        src:'wikipedia',
        year: year
      }

      $redis.lpush(REDIS_OUTPUT_QUEUE, output.to_json)
    end
end

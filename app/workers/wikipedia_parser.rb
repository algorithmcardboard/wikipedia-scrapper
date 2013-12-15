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

    duplicate_events = Hash.new

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

    return if(duplicate_events.blank?)

    #process only for duplicates
    
    calculateEditDistanceAndPush(duplicate_events, threshold)
  end

  private

    def calculateEditDistanceAndPush(duplicate_events, threshold)
      ids = duplicate_events.keys
      Event.select(:id, :name, :event, :year, :category_id).where(["id in (?)",ids]).each do |event|
        duplicate_events[event.id.to_s].each do |wiki_text|
          
          wiki_node = Nokogiri::HTML(wiki_text)
          belongs_to = nil

          if(editDistance(event.name, event.event, wiki_node) < threshold)
            belongs_to = event.id
          end

          parseAndPushToRedisOutputQueue(event.year, wiki_node, belongs_to, event.category_id)
        end
      end
    end

    def processEventsInPage(month, day, headline_div)

      possible_duplicate_events = Hash.new

      category_id = Rails.application.config.wiki_tih_mapping[headline_div.text]
      logger.info "known headline #{headline_div.text} with category_id #{category_id}"

      unpushed = pushed = 0

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
      event_node.css("a").each do |anchor|
        anchor['href'] = WIKIPEDIA_PREFIX + anchor['href']
      end
    end
end

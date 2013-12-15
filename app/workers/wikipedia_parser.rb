# encoding: UTF-8

require 'open-uri'
require 'set'

class WikipediaParser
  include Sidekiq::Worker, RedisService

  WIKIPEDIA_PREFIX = 'http://en.wikipedia.org';

  def perform(month, day)
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

    duplicate_events.each do |key, value|
      logger.info "#{key} => #{value.size()}"
    end
  end

  private

    def processEventsInPage(month, day, headline_div)

      possible_duplicate_events = Hash.new

      category_id = Rails.application.config.wiki_tih_mapping[headline_div.text]
      logger.info "known headline #{headline_div.text} with category id #{category_id}"

      unpushed = pushed = 0

      headline_div.parent.next_element.css("li").each do |event_node|

        event_node.name = 'span'
        #parse and get year and text.  Split text to array and remove stop words
        year, event_text = event_node.text.split("–", 2)
        year = getYearValueInInt(year)
        event_words = event_text.downcase.gsub(/[^\w\d ]/," ").split - Rails.application.config.stop_words

        year_key =  getYearKey(category_id, year, month, day)
        events_on_year = $redis.smembers(year_key)

        #if no events for the year. There is no point in searching with words. Just push the text directly to the output stream
        if(events_on_year.blank?)
          parseAndPushToRedisOutputQueue(year, event_node)
          pushed += 1
          next
        end

        common_events = Hash.new

        event_words.each do |word|
          cur_event = Hash[$redis.sinter(year_key, getTextKey(category_id, word, month, day) ).map{|elem| [elem,1]}]
          #intersect cur_event and common_events and add the number of times we have seen a particular event 
          #.  This will help us calculate cosine similarity
          common_events.merge!(cur_event) {|key,val1,val2| val1+val2}
        end

        #remove all entries that doesn't meet a threshold
        common_events.select!{|event_id,count| isSimilar(count, event_words.length, $redis.get(getKeyForLength(event_id)).to_i)}

        if(common_events.blank?)
          parseAndPushToRedisOutputQueue(year, event_node)
          pushed += 1
          next
        end

        logger.debug "Not pushing directly for year #{year} #{category_id} #{common_events} #{event_words}"
        unpushed += 1

        #collect all the duplicates
        common_events.each do |event_id,count|
          logger.debug "adding for event #{event_id}"
          if(possible_duplicate_events[event_id].blank?)
            logger.debug "creating a new set for event #{event_id}"
            possible_duplicate_events[event_id] = Set.new
          end

          possible_duplicate_events[event_id].add(event_node.to_s)
        end

      end
      logger.info "#{pushed} pushed directly.  #{unpushed} yet to be processed"

      possible_duplicate_events
    end

    def getYearValueInInt(year)
      year = year.strip
      mul_factor = 1;

      if(year.match(/.* BC$/))
        mul_factor = -1
      end

      return mul_factor * year.to_i
    end

    def isDateAnchor(anchorHref)
      if(anchorHref.match(/^\/wiki\/\d+$|\d+_BC$/))
        return true
      end
      return false
    end

    def getTitleFromHREF(anchorHref)
      link = anchorHref.split('/').last
      if(link.match(/#/))
         link = link.split('#',2).last
      end

      link.tr("_"," ")
    end

    def parseAndPushToRedisOutputQueue(year, event_node)
      event_node.css("a").each do |anchor|
        anchor['href'] = WIKIPEDIA_PREFIX + anchor['href']
      end
    end

    def isSimilar(count_similar, wc_new, wc_existing)
      #cosine similarity
      similarity_score = count_similar/(Math.sqrt(wc_new) * Math.sqrt(wc_existing))
      return similarity_score > 0.45
    end
end

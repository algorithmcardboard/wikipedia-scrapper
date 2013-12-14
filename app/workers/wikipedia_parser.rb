# encoding: UTF-8

require 'open-uri'

class WikipediaParser
  include Sidekiq::Worker

  def perform(month, day)
    logger.info "Got #{month} #{day} as arguments"

    month_name = Rails.application.config.months_name[month - 1]

    wikipedia_url = "http://en.wikipedia.org/wiki/#{month_name}_#{day}"
    logger.info wikipedia_url

    doc = Nokogiri::HTML(open(wikipedia_url))

    doc.css('.mw-headline').each do |headline_div|

      unless (Rails.application.config.allowed_wiki_headlines.has_key?(headline_div.text))
        logger.error "Unknown headline #{headline_div.text}from wikipedia.  Might be a unobserved case. Investigate." 
        next
      end

      unless( Rails.application.config.allowed_wiki_headlines[headline_div.text] )
        logger.info "skipping #{headline_div.text}. not in allowed list"
        next
      end

      processEventsInPage(month, day, headline_div)
    end
  end

  private

    def processEventsInPage(month, day, headline_div)
      category_id = Rails.application.config.wiki_tih_mapping[headline_div.text]
      logger.info "known headline #{headline_div.text} with category id #{category_id}"

      unpushed = 0;

      headline_div.parent.next_element.css("li").each do |event|
        year, event_text = event.text.split("–", 2)
        logger.info event_text
        year = getYearValueInInt(year)
        event_words = event_text.downcase.gsub(/[^\w\d ]/," ").split - Rails.application.config.stop_words

        events_on_year = $redis.smembers("YEAR:#{day}-#{month}-#{year}")

        if(events_on_year.blank?)
          parseAndPushToRedisOutputQueue(year, event)
        end

        logger.info "Not pushing directly for year #{year} #{events_on_year} #{event_words}"
        unpushed += 1
      end
      logger.info "total unpushed is #{unpushed}"
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
    end
end

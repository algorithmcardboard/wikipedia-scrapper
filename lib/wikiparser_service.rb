module WikiparserService

    def getTitleFromHREF(anchorHref)
      link = anchorHref.split('/').last
      if(link.match(/#/))
         link = link.split('#',2).last
      end
      link.tr("_"," ")

      return link
    end

    def isDateAnchor(anchorHref)
      if(anchorHref.match(/^\/wiki\/\d+$|\d+_BC$/))
        return true
      end
      return false
    end

    def getYearValueInInt(year)
      year = year.strip
      mul_factor = 1;

      if(year.match(/.* BC$/))
        mul_factor = -1
      end

      return mul_factor * year.to_i
    end

    def getEventDetailsForPersisting(wiki_text,category_id)
      year, event_text = Nokogiri::HTML::fragment(wiki_text).text.split("–",2)
      year = getYearValueInInt(year)
      name = ""

      if(category_id == 37 || category_id == 38)
        name, event_text = event_text.split(",",2)
      end
      return [year, name.strip, event_text.strip]
    end

end

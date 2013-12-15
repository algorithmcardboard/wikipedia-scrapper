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

end

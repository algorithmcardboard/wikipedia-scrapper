module SimilarityService

  def isSimilar(count_similar, wc_new, wc_existing)
    #cosine similarity
    similarity_score = count_similar/(Math.sqrt(wc_new) * Math.sqrt(wc_existing))
    return similarity_score > 0.45
  end

  def editDistance(name, event, wiki_node)
    return 0
  end
end

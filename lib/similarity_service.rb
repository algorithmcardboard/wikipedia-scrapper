module SimilarityService

  def isSimilar(count_similar, wc_new, wc_existing)
    #cosine similarity
    similarity_score = count_similar/(Math.sqrt(wc_new) * Math.sqrt(wc_existing))
    return similarity_score > 0.45
  end

  # 
  # is same as  http://rosettacode.org/wiki/Levenshtein_distance#Ruby
  # Donno why i changed the variable names alone!!
  #
  def editDistance(sentence1, sentence2)
    first_array = sentence1.downcase.gsub(/[^\w\d ]/," ").split - Rails.application.config.stop_words
    second_array = sentence2.downcase.gsub(/[^\w\d ]/," ").split - Rails.application.config.stop_words

    l1 = first_array.length
    l2 = second_array.length

    return l2 if l1 == 0
    return l1 if l2 == 0

    d = Array.new(l1+1) {Array.new(l2+1)}

    (0..l1).each {|i| d[i][0] = i}
    (0..l2).each {|j| d[0][j] = j}

    (1..l2).each do |j|
      (1..l1).each do |i|
        d[i][j] = 
            if first_array[i-1] == second_array[j-1]  # adjust index into string
              d[i-1][j-1]       # no operation required
            else
              [ d[i-1][j]+1,    # deletion
                d[i][j-1]+1,    # insertion
                d[i-1][j-1]+1,  # substitution
              ].min
            end
      end
    end
  d[l1][l2]
  end
end

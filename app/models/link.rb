class Link < ActiveRecord::Base
  has_many :events_link
  has_many :events, through: :events_link

  #validates_uniqueness_of :url, :scope => [:name]
end

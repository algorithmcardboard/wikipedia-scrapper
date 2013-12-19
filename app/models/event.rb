class Event < ActiveRecord::Base
  belongs_to :category
  has_many :events_link
  has_many :links, through: :events_link

  before_save :default_values

  def default_values
    self.has_image = 0 if self.has_image.nil?
  end
end

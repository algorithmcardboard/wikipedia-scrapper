class EventsLink < ActiveRecord::Base
  belongs_to :event
  belongs_to :link
end

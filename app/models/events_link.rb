require 'composite_primary_keys'

class EventsLink < ActiveRecord::Base
  belongs_to :event
  belongs_to :link

  self.primary_keys = [:event_id, :link_id]

  def insert_ignore
    query = "INSERT IGNORE INTO events_links(event_id, link_id) VALUES(#{event_id}, #{link_id})"
    EventsLink.connection.insert_sql(query)
  end
end

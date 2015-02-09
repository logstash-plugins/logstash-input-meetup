# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "socket" # for Socket.gethostname

# Run command line tools and capture the whole output as an event.
#
# Notes:
#
# * The `@source` of this event will be the command run.
# * The `@message` of this event will be the entire stdout of the command
#   as one event.
#
class LogStash::Inputs::Meetup < LogStash::Inputs::Base

  config_name "meetup"

  # URLName - the URL name ie `ElasticSearch-Oklahoma-City`
  # Must have one of urlname, venue_id, group_id
  config :urlname, :validate => :string

  # The venue ID
  # Must have one of `urlname`, `venue_id`, `group_id`
  config :venueid, :validate => :string

  # The Group ID, multiple may be specified seperated by commas
  # Must have one of `urlname`, `venueid`, `groupid`
  config :groupid, :validate => :string

  # Interval to run the command. Value is in seconds.
  config :interval, :validate => :number, :required => true

  # Meetup Key
  config :meetupkey, :validate => :string, :required => true

  # Event Status'
  config :eventstatus, :validate => :string, :default => "upcoming,past"

  public
  def register
    require "faraday"
    # group_id
    if groupid
	addon = "group_id=#{ @groupid }"
    # group_urlname
    elsif urlname
	addon = "group_urlname=#{ @urlname }"
    # venue_id
    elsif venueid
	addon = "venue_id=#{ @venueid }"
    else
    # None Selected, raise an error
	addon = ""
    end
    @url = "https://api.meetup.com/2/events.json?key=#{ @meetupkey }&status=#{ @eventstatus }&#{ addon }"
    @logger.info("Registering meetup Input", :url => @url, :interval => @interval)
  end # def register

  public
  def run(queue)
    Stud.interval(@interval*60) do
      start = Time.now
      @logger.info? && @logger.info("Polling meetup", :url => @url)

      # Pull down the RSS feed using FTW so we can make use of future cache functions
      response = Faraday.get @url
      result = JSON.parse(response.body)

      result["results"].each do |rawevent| 
        event = LogStash::Event.new(rawevent)
        # Convert the timestamps into Ruby times
        event['created'] = LogStash::Timestamp.at(event['created'] / 1000, (event['created'] % 1000) * 1000)
        event['time'] = LogStash::Timestamp.at(event['time'] / 1000, (event['time'] % 1000) * 1000)
        event['group']['created'] = LogStash::Timestamp.at(event['group']['created'] / 1000, (event['group']['created'] % 1000) * 1000)
        event['updated'] = LogStash::Timestamp.at(event['updated'] / 1000, (event['updated'] % 1000) * 1000)
	event['venue']['lonlat'] = [event['venue']['lon'],event['venue']['lat']] if rawevent.has_key?('venue')
        event['group']['lonlat'] = [event['group']['group_lon'],event['group']['group_lat']] if rawevent.has_key?('group')
        decorate(event)
        queue << event
      end

      duration = Time.now - start
      @logger.info? && @logger.info("poll completed", :command => @command,
                                    :duration => duration)
    end # loop
  end # def run
end # class LogStash::Inputs::Exec

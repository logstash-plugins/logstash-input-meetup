# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "logstash/json"
require "socket" # for Socket.gethostname

# Periodically query meetup.com regarding updates on events for the given meetupkey
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

  # Interval to run the command. Value is in minutes.
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
      begin
        result = LogStash::Json.load(response.body)
      rescue LogStash::Json::ParserError
        # silently ignore json parsing errors
      end

      result["results"].each do |rawevent|
        event = LogStash::Event.new(rawevent)
        # Convert the timestamps into Ruby times
        event.set('created', LogStash::Timestamp.at(event.get('created') / 1000, (event.get('created') % 1000) * 1000))
        event.set('time', LogStash::Timestamp.at(event.get('time') / 1000, (event.get('time') % 1000) * 1000))
        event.set('[group][created]', LogStash::Timestamp.at(event.get('group][created]') / 1000, (event.get('group][created]') % 1000) * 1000))
        event.set('updated', LogStash::Timestamp.at(event.get('updated') / 1000, (event.get('updated') % 1000) * 1000))
        event.set('[venue][lonlat]', [event.get('[venue][lon]'), event.get('[venue][lat]') if rawevent.has_key?('venue'))
        event.set('[group][lonlat]', [event.get('[group][group_lon]',event'[group][group_lat]') if rawevent.has_key?('group'))
        decorate(event)
        queue << event
      end

      duration = Time.now - start
      @logger.info? && @logger.info("poll completed", :command => @command,
                                    :duration => duration)
    end # loop
  end # def run
end # class LogStash::Inputs::Exec

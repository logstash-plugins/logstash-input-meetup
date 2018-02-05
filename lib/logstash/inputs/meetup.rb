# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "logstash/json"
require "socket" # for Socket.gethostname

# Periodically query meetup.com regarding updates on events for the given meetupkey
class LogStash::Inputs::Meetup < LogStash::Inputs::Base

  config_name "meetup"

  # URLName - the URL name ie `ElasticSearch-Oklahoma-City`
  # Must have one of urlname, venue_id, group_id, or text
  config :urlname, :validate => :string

  # The venue ID
  # Must have one of `urlname`, `venue_id`, `group_id`, or 'text'
  config :venueid, :validate => :string

  # The Group ID, multiple may be specified seperated by commas
  # Must have one of `urlname`, `venueid`, `groupid`, or 'text'
  config :groupid, :validate => :string

  # A text string, AND_text is set to true
  # Must have one of urlname, venue_id, group_id, or text
  config :text, :validate => :string

  # Interval to run the command. Value is in minutes.
  config :interval, :validate => :number, :required => true

  # Meetup Key
  config :meetupkey, :validate => :password, :required => true

  # Event Status'
  config :eventstatus, :validate => :string, :default => "upcoming,past"

  public
  def register
    require "faraday"

    if text
      # do this
        addon = "text=#{ @text }&and_text=true"
        @url = "https://api.meetup.com/2/open_events.json?key=#{ @meetupkey }&#{ addon }"
    else
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
        raise "Configuration error! -  Must have one of `urlname`, `venue_id`, or `group_id` defined"
        addon = ""
      end

      @url = "https://api.meetup.com/2/events.json?key=#{ @meetupkey.value }&status=#{ @eventstatus }&#{ addon }"
    end

    @logger.info("Registering meetup Input", :url => @url.gsub(@meetupkey.value, "xxxx"), :interval => @interval)
  end  # def register

  public
  def run(queue)
    Stud.interval(@interval*60) do
      start = Time.now
      @logger.info? && @logger.info("Polling meetup", :url => @url)

      # Pull down the RSS feed using FTW so we can make use of future cache functions
      response = Faraday.get @url
      logger.error("Error call meetup API: " + response.body) unless response.status.eql?(200)
      begin
        result = LogStash::Json.load(response.body)
      rescue LogStash::Json::ParserError => e
        # ignore json parsing errors
        logger.debug("Error parsing Json", :message => e.message, :backtrace => e.backtrace)
      end

      result["results"].each do |rawevent|
        # handling MU's "relevant" but not matching results
        next if rawevent['description'].nil? 
        next unless rawevent['description'].downcase.include? @text.downcase

        event = LogStash::Event.new(rawevent)
        # Convert the timestamps into Ruby times
        event.set('created', LogStash::Timestamp.at(event.get('created') / 1000, (event.get('created') % 1000) * 1000))
        event.set('time', LogStash::Timestamp.at(event.get('time') / 1000, (event.get('time') % 1000) * 1000))
        event.set('[group][created]', LogStash::Timestamp.at(event.get('group][created]') / 1000, (event.get('group][created]') % 1000) * 1000))
        event.set('updated', LogStash::Timestamp.at(event.get('updated') / 1000, (event.get('updated') % 1000) * 1000))
        event.set('[venue][lonlat]', [event.get('[venue][lon]'), event.get('[venue][lat]')]) if rawevent.has_key?('venue')
        event.set('[group][lonlat]', [event.get('[group][group_lon]'), event.get('[group][group_lat]')]) if rawevent.has_key?('group')
        event.set('[rating][average]', event.get('[rating][average]').round) if rawevent.has_key?('rating')       
        decorate(event)
        queue << event
      end

      duration = Time.now - start
      @logger.info? && @logger.info("poll completed", :command => @command,
                                    :duration => duration)
    end # loop
  end # def run
end # class LogStash::Inputs::Exec

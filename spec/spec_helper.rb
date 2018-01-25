require 'logstash/devutils/rspec/spec_helper'
require 'logstash/inputs/meetup'
require 'logstash/codecs/plain'
require 'webmock/rspec'

# JSON fixture helper
module MeetupFixtures
  def fixture(filename)
    File.read(File.expand_path(File.join('spec', 'fixtures', filename)))
  end
end

RSpec.configure do |c|
  c.include MeetupFixtures
end

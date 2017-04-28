# encoding: utf-8

require_relative '../../spec_helper'

describe LogStash::Inputs::Meetup do
  before do
    WebMock.disable_net_connect! allow_localhost: true
  end

  after do
    WebMock.allow_net_connect!
  end

  let(:meetupkey) { SecureRandom.hex 14 }
  let(:groupid) { (1..2).map { rand(10_000_000) }.join(',') }
  let(:config) do
    {
      'meetupkey' => meetupkey,
      'groupid' => groupid,
      'interval' => 1
    }
  end
  let(:subject) { described_class.new(config) }
  let(:queue) { Queue.new }

  it 'fetches JSON from the Meetup API' do
    api = 'https://api.meetup.com/2/events.json'
    url = "#{api}?group_id=#{groupid}&key=#{meetupkey}&status=upcoming,past"

    stub_request(:get, url).to_return(body: fixture('meetup-response.json'))

    subject.register
    Thread.new { subject.run(queue) }
    sleep 0.01 while queue.size.zero?

    expect(a_request(:get, url)).to have_been_made.at_least_once
  end
end

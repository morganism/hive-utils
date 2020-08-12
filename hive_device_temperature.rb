# morgan.sziraki@gmail.com
# simple API response parser to extract temperature from 
# any device in your nodes that support an xpath like
# ['attributes']['temperature']['reportedValue']
#
#  Mon 13 Nov 2017 10:21:56 GMT

require 'json'
require 'net/http'
require 'openssl'
require 'optparse'
require 'uri'

api_token = ENV['API_TOKEN'] if ENV['API_TOKEN']

OptionParser.new do |opts|
    opts.banner = "Usage: hive-api-tool.rb [options]\n  *** Only GET method supported. ***"
    opts.on('-t', '--api-token[API_TOKEN]', 'the API token (or export API_TOKEN)') { |o| api_token = o }
    opts.on_tail('-h', '--help') {
      puts opts
      exit
    }
end.parse!

if api_token.nil?
  raise StandardError, 'You need to export API_TOKEN as an environmental variable'
end

BASE_URL = 'https://api.prod.bgchprod.info/omnia'

def process(node)
    unless node['attributes']['temperature'].nil?
        device = node['name']
        state = nil
        target_temp = nil
        if node['name'].eql?('Receiver')
          device = 'Thermostat'
          state = node['attributes']['stateHeatingRelay']['reportedValue']
          target_temp = node['attributes']['targetHeatTemperature']['reportedValue']
        end
        current_temp = node['attributes']['temperature']['reportedValue']
        {
            :device       => device,
            :time         => now,
            :current_temp => (decimal current_temp),
            :target_temp  => (decimal target_temp),
            :state        => state

        }
    end
end

# format n to n.00, n.x to n.x0, .n to 0.n0
def decimal(n, s = 2)
  begin
    "%.#{s}f" % n
  rescue ArgumentError, TypeError # carry on and keep 
    ''
  end
end

def now
  Time.now.strftime("%Y%m%d%H%M%S")
end

def parse
    uri = URI.parse("#{BASE_URL}/nodes")
    request = Net::HTTP::Get.new(uri)
    request['Accept'] = 'application/vnd.alertme.zoo-6.0.0+json'
    request['X-Omnia-Client'] = 'swagger'
    request['X-Omnia-Access-Token'] = ENV['API_TOKEN']

    req_options = {
      use_ssl: uri.scheme == 'https',
      verify_mode: OpenSSL::SSL::VERIFY_NONE,
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
end

# this is ugly, i promise to make beautiful pretzel colon and .method! stuff
nodes_hash = JSON.parse(parse.response.body)
x = nodes_hash['nodes'].each_with_object([]) do |node, nodes|
  result = process(node)
  nodes << result unless (result.nil?)
end
puts JSON.dump(x)

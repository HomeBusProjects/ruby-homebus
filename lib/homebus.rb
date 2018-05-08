require 'net/http'
require 'pp'

class HomeBus
  # in order to provision, we contact
  # HomeBus.local/provision
  # and POST a json payload of { provision: { mac_address: 'xx:xx:xx:xx:xx:xx' } }
  # you get back another JSON object
  # uuid, mqtt_hostname, mqtt_port, mqtt_username, mqtt_password
  # save this in .env.provision and return it in the mqtt parameter
  def self.provision(mac_address)
    uri = URI('http://127.0.0.1:3000/provision')

    request = {
      provision: {
        mac_address: mac_address
      }
    }

    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = request.to_json

    res = Net::HTTP.start(uri.hostname, uri.port) do |http|
      res = http.request(req)

      return nil unless res.code == "200"

      answer = JSON.parse res.body, symbolize_names: true

      mqtt = Hash.new
      mqtt[:host] = answer[:mqtt_hostname]
      mqtt[:port] = answer[:mqtt_port]
      mqtt[:username] = answer[:mqtt_username]
      mqtt[:password] = answer[:mqtt_password]
      mqtt[:uuid] = answer[:uuid]
      
      return mqtt
    end

    return nil
  end
end

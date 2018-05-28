require 'net/http'
require 'pp'

class HomeBus
  # in order to provision, we contact
  # HomeBus.local/provision
  # and POST a json payload of { provision: { mac_address: 'xx:xx:xx:xx:xx:xx' } }
  # you get back another JSON object
  # uuid, mqtt_hostname, mqtt_port, mqtt_username, mqtt_password
  # save this in .env.provision and return it in the mqtt parameter
  def self.provision(args)
    provisioner_name = args[:provisioner_name] || '127.0.0.1'
    provisioner_port = args[:provisioner_port] || 80

    uri = URI("http://#{provisioner_name}:#{provisioner_port}/provision")

#    provision = {}
#    provision.merge args
#    provision.require([:friendly_name, :manufacturer, :model_number, :serial_number, :pin, :wo_topics, :ro_topics, :rw_topics])

    provision = args

    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = {
      provision: provision
    }.to_json


    status = "waiting"

    # make sure answer is in scope
    answer = nil
    begin
      res = Net::HTTP.start(uri.hostname, uri.port) do |http|
        res = http.request(req)

        return nil unless res.code == "200" || res.code == '201'

        answer = JSON.parse res.body, symbolize_names: true
        status = answer[:status]
        sleep(answer[:retry_time].to_i) if(status == 'waiting')
      end while(status == 'waiting')

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

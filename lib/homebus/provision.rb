require 'homebus/homebus'

require 'cgi'

class Homebus::Provision
  attr_accessor :homebus_server
  attr_accessor :id, :name, :token, :consumes, :publishes, :devices, :retry_interval
  attr_accessor :broker_hostname, :broker_username, :broker_password, :broker_port, :broker_uri

  def initialize(**args)
    unless [:name, :consumes, :publishes, :homebus_server].all? { |s| args.key? s }
      raise 'Arguments must contain all of :consumes, :publishes, :homebus_server'
    end

    self.id = args[:id] if args[:id]

    self.name = args[:name]
    self.consumes = args[:consumes] || []
    self.publishes = args[:publishes] || []
    self.homebus_server = args[:homebus_server]
    self.devices = []
  end

  def add_device(device)
    @devices.push device
  end

  # in order to provision, we contact
  # HomeBus.local/provision
  # and POST a json payload of { provision: { mac_address: 'xx:xx:xx:xx:xx:xx' } }
  # you get back another JSON object
  # uuid, mqtt_hostname, mqtt_port, mqtt_username, mqtt_password
  # save this in .env.provision and return it in the mqtt parameter
  def provision(token)
    url = "#{@homebus_server}/api/provision_requests"
    uri = URI(url)

    provision_request = {
      name: @name,
      devices: @devices.map { |d| d.to_hash },
      consumes: @consumes,
      publishes: @publishes
    }

    if @id
      raise Homebus::Provision:AlreadyCreated
    end

    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = provision_request.to_json

    req['Content-Type'] = 'application/json'
    req['AUTHORIZATION'] = 'Bearer ' + token

    Net::HTTP.start(uri.hostname, uri.port) do |http|
      res = http.request(req)

      return _process_response(res)
    end
  end

  def _process_response(res)
    if res.code == '401'
      raise Homebus::Provision::InvalidToken
    end

    if res.code != '200' && res.code != '202'
      return false
    end

    answer = JSON.parse res.body, symbolize_names: true

    if answer[:retry_interval]
      @id = answer[:provision_request][:id]
      @token = answer[:provision_request][:token]
      @retry_interval = answer[:retry_interval]

      return false
    end

    unless answer[:broker] && answer[:credentials]
      raise Homebus::Provision::InvalidResponse
    end

    pp answer[:broker]

    @broker_hostname = answer[:broker][:mqtt_hostname]
    @broker_port = answer[:broker][:secure_mqtt_port]
    @broker_username = answer[:credentials][:mqtt_username]
    @broker_password = answer[:credentials][:mqtt_password]

    @broker_uri = "mqtts://#{CGI.escape(@broker_username)}:#{CGI.escape(@broker_password)}@#{@broker_hostname}:#{@broker_port}"

    @retry_interval = nil

    return true
  end

  def get
    raise 'Not yet provisioned' unless @id

    url = "#{@homebus_server}/api/provision_requests/#{@id}"
    uri = URI(url)

    devices = []
    @devices.each do |device|
      devices.push device.to_hash
    end

    provision_request = {
      name: @name,
      id: @id,
      devices: @devices.map { |d| d.to_hash },
      consumes: @consumes,
      publishes: @publishes
    }

    req = Net::HTTP::Get.new(uri, 'Content-Type' => 'application/json')
    req.body = provision_request.to_json

    req['Content-Type'] = 'application/json'
    req['AUTHORIZATION'] = 'Bearer ' + @token

    Net::HTTP.start(uri.hostname, uri.port) do |http|
      res = http.request(req)
      return _process_response(res)
    end
  end

  def provision!(token)
    results = provision(token)

    loop do
      if results
        return true
      end

      sleep(15)

      results = get
    end
  end


  def to_hash
    value = {
      name: name,
      consumes: consumes,
      publishes: publishes,
      devices: devices.map do |d| { name: d[:name], identity: d[:identity], id: d[:id], token: d[:token] } end,
    }

    if id
      value[:id] = id
    end

    if token
      value[:token] = token
    end

    if self.broker_hostname
      value[:broker_hostname] = broker_hostname
      value[:broker_port] = broker_port
      value[:broker_uri] = broker_uri
      value[:broker_username] = broker_username
      value[:broker_password] = broker_password
    end

    value
  end
end

class Homebus::Provision::InvalidToken < Exception
end

class Homebus::Provision::InvalidProvisioningServer < Exception
end

class Homebus::Provision::InvalidResponse < Exception
end

class Homebus::Provision::AlreadyCreated < Exception
end


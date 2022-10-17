require 'homebus/homebus'

require 'cgi'

class Homebus::Provision 
  attr_accessor :homebus_server
  attr_accessor :status
  attr_accessor :id, :name, :token, :consumes, :publishes, :devices, :retry_interval
  attr_accessor :broker
  
  def initialize(**args)
    unless [:name, :consumes, :publishes].all? { |s| args.key? s }
      raise 'Arguments must contain all of :name, :consumes, :publishes'
    end

    @id = args[:id] if args[:id]
    @token = args[:token] if args[:token]

    @name = args[:name]
    @consumes = args[:consumes] || []
    @publishes = args[:publishes] || []
    @homebus_server = args[:homebus_server]
    @status = args[:status]
    @devices = args[:devices] || []

    @status = :init
    @broker = Homebus::Broker.new
  end

  def add_device(device)
    @devices.push device
  end

  def provision(token)
    case status
    when :init
      return _provision(token)
    when :wait
      return _get
    when :provisioned
      return true
    else
      return false
    end
  end

  def provision!(token)
    return true if status == :provisioned

    if status == :wait
      results = get
    else
      results = provision(token)
    end

    loop do
      if status == :provisioned
        return true
      end

      sleep(15)

      results = get
    end
  end

  def exit_when_safe!
    while @broker.outstanding_publishes?
      sleep 0.1
    end
  end

  def to_hash
    value = {
      homebus_server: @homebus_server,
      status: @status,
      provision_request: {
        name: @name,
        consumes: @consumes,
        publishes: @publishes,
        devices: @devices.map { |d| d.to_hash }
      }
    }

    if @id
      value[:provision_request][:id] = @id
      value[:provision_request][:token] = @token
    end

    if @status == :provisioned
      broker_hash = @broker.to_config

      if broker_hash
        value.merge! broker_hash
      end
    end

    value
  end

  def self.from_config(obj)
    return nil unless obj

    unless obj[:provision_request]
      raise Homebus::Provision::InvalidDeserialization
    end

    pr = Homebus::Provision.new obj[:provision_request]

    pr.homebus_server = obj[:homebus_server]
    pr.status = obj[:status].to_sym

    pr.devices = []

    obj[:provision_request][:devices].each do |d|
      device = Homebus::Device.from_config(d)
      device.provision = pr

      pr.devices.push device
    end

    pr.broker = Homebus::Broker.from_config(obj)

    return pr
  end

  private

  def _provision(token)
    url = "#{@homebus_server}/api/provision_requests"
    uri = URI(url)

    provision_request = {
      name: @name,
      devices: @devices.map { |d| d.to_hash },
      consumes: @consumes,
      publishes: @publishes
    }

    puts 'devices'
    puts @devices

    if @id
      raise Homebus::Provision::AlreadyCreated
    end

    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = provision_request.to_json

    puts req.body

    req['Content-Type'] = 'application/json'
    req['AUTHORIZATION'] = 'Bearer ' + token

    ssl = homebus_server.include?('https:')

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: ssl) do |http|
      res = http.request(req)

      return _process_response(res)
    end
  end


  def _get
    raise 'Not yet provisioned' unless status == :wait || status == :provisioned

    url = "#{@homebus_server}/api/provision_requests/#{@id}"
    uri = URI(url)

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

    ssl = homebus_server.include?('https:')

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: ssl) do |http|
      res = http.request(req)
      return _process_response(res)
    end
  end

  def _process_response(res)
    if res.code == '401'
      @status = :invalid_token
      raise Homebus::Provision::InvalidToken
    end

    if res.code != '200' && res.code != '201' && res.code != '202' 
      puts "response code #{res.code}"
      @status = :invalid_response
      raise Homebus::Provision::InvalidResponse
    end

    answer = JSON.parse res.body, symbolize_names: true

    if answer[:retry_interval]
      @status = :wait

      @id = answer[:provision_request][:id] if answer[:provision_request][:id]
      @token = answer[:provision_request][:token] if answer[:provision_request][:token]
      @retry_interval = answer[:retry_interval]

      return false
    end

    unless answer[:broker] && answer[:credentials]
      @status = :invalid_response

      raise Homebus::Provision::InvalidResponse
    end

    @status = :provisioned

    @broker.host = answer[:broker][:mqtt_hostname]
    @broker.port = answer[:broker][:secure_mqtt_port]
    @broker.username = answer[:credentials][:mqtt_username]
    @broker.password = answer[:credentials][:mqtt_password]

    @retry_interval = nil

    if answer[:devices]
      answer[:devices].each do |d|
        local_device = @devices.select { |ld|
          i = d[:identity]
          ld.manufacturer == i[:manufacturer] &&
          ld.model == i[:model] &&
          ld.serial_number == i[:serial_number]
        }[0]

        if local_device
          local_device.token = d[:token]
          local_device.id = d[:id]
        else
          raise Homebus::Provision::DeviceMismatch
        end
      end
    end

    return true
  end

end

class Homebus::Provision::InvalidDeserialization < Exception
end

class Homebus::Provision::InvalidToken < Exception
end

class Homebus::Provision::InvalidProvisioningServer < Exception
end

class Homebus::Provision::InvalidResponse < Exception
end

class Homebus::Provision::AlreadyCreated < Exception
end

class Homebus::Provision::DeviceMismatch < Exception
end


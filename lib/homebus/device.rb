require 'homebus/homebus'

class Homebus::Device
  attr_accessor :id, :name, :manufacturer, :model, :serial_number, :pin, :token, :provision

  def initialize(**args)
    unless [:name, :manufacturer, :model, :serial_number].all? { |s| args.key? s }
      raise 'Arguments must contain all of :name, :manufacturer, :model, :serial_number'
    end

    @name = args[:name]
    @id = args[:id] if args[:id]
    @token = args[:token] if args[:token]

    @manufacturer = args[:manufacturer] || ''
    @model = args[:model] || ''
    @serial_number = args[:serial_number] || ''
    @pin = args[:pin] || ''
  end

  def create
    url = "#{@homebus_server}/api/devices"
    uri = URI(url)

    devices = []
    @devices.each do |device|
      devices.push device.to_hash
    end

    device_post = {
      name: @name,
      identity: {
        manufacturer: @manufacturer,
        model: @model,
        serial_number: @serial_number
      },
      provision_request_id: @provision_request.id
    }

    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = device_post.to_json

    req['Content-Type'] = 'application/json'
    req['AUTHORIZATION'] = 'Bearer ' + @provision_request.token

    # make sure answer is in scope
    answer = nil

    Net::HTTP.start(uri.hostname, uri.port) do |http|
      res = http.request(req)

      return nil unless res.code == "200" || res.code == '201'

      answer = JSON.parse res.body, symbolize_names: true
      return answer if(answer[:status] == 'waiting')
    end

    @id = answer[:id]
    @token = answer[:token]

    return answer
  end

  def publish!(ddc, msg)
    @provision.broker.publish!(@id, ddc, msg)
  end

  def to_hash
    value = {
      name: @name,
      identity: {
        manufacturer: @manufacturer,
        model: @model,
        serial_number: @serial_number,
        pin: @pin
      }
    }

    if @id
      value[:id] = @id
    end

    if @token
      value[:token] = @token
    end

    return value
  end

  def self.from_config(obj)
    device = Homebus::Device.new(name: obj[:name],
                                 manufacturer: obj[:identity][:manufacturer],
                                 model: obj[:identity][:model],
                                 serial_number: obj[:identity][:serial_number]
                                )

    device.id = obj[:id] if obj[:id]
    device.token = obj[:token] if obj[:token]

    return device
  end
end

  

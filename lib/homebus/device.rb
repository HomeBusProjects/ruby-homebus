require 'homebus/homebus'

class Homebus::Device
  attr_accessor :id, :name, :manufacturer, :model, :serial_number, :pin, :token

  def initialize(**args)
    unless [:name, :manufacturer, :model, :serial_number, :provision].all? { |s| args.key? s }
      raise 'Arguments must contain all of :name, :manufacturer, :model, :serial_number, :provision'
    end

    self.name = args[:name]
    self.id = args[:id] if args[:id]
    self.token = args[:token] if args[:token]

    self.manufacturer = args[:manufacturer] || ''
    self.model = args[:model] || ''
    self.serial_number = args[:serial_number] || ''
    self.pin = args[:pin] || ''
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

    if @id
      provision_request[:id] = @id
    end

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

    self.id = answer[:id]
    self.token = answer[:token]

    return answer
  end

  def to_hash
    value = {
      name: self.name,
      identity: {
        manufacturer: self.manufacturer,
        model: self.model,
        serial_number: self.serial_number,
        pin: self.pin
      }
    }

    if self.id
      value[:id] = self.id
    end

    if self.token
      value[:token] = self.token
    end

    value
  end
end

  

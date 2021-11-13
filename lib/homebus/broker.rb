require 'homebus/broker'

class Homebus::Broker
  attr_accessor :uri, :host, :port, :username, :password

  def initialize(**args)
    @host = args[:host] if args[:host]
    @port = args[:port] if args[:port]
    @username = args[:username] if args[:username]
    @password = args[:password] if args[:password]
    @uri = args[:uri] if args[:uri]

    if @host && @port && @username && @password && !@uri
      @uri = _make_uri
    end
  end

  def connect!
    unless host && port && username
      abort 'no broker'
    end

    puts @uri
    @mqtt = MQTT::Client.connect(@uri)
  end

  def configured?
    host && port && username && password && uri
  end

  def connected?
    @mqtt && @mqtt.connected?
  end

  def publish!(id, ddc, msg)
    homebus_msg = {
      source: id,
      timestamp: Time.now.to_i,
      contents: {
        ddc: ddc,
        payload: msg
      }
    }

    json = JSON.generate(homebus_msg)
    @mqtt.publish "homebus/device/#{id}/#{ddc}", json, true
  end

  def subscribe!(*ddcs)
    ddcs.each do |ddc| @mqtt.subscribe 'homebus/device/+/' + ddc end
  end

  def subscribe_to_sources!(*ids)
    ids.each do |id|
      topic =  'homebus/device/' + id
      @mqtt.subscribe topic
    end
  end

  def to_config
    unless host && port && username && password
      return nil
    end

    unless uri
      @uri = _make_uri
    end

    { broker: {
        hostname: host,
        port: port,
        uri: uri
      },
      credentials: {
        username: username,
        password: password
      }
    }
  end

  def self.from_config(obj)
    unless obj[:broker] && obj[:credentials]
      puts 'empty'
      return Homebus::Broker.new
    end

    br = Homebus::Broker.new(host: obj[:broker][:hostname],
                             port: obj[:broker][:port],
                             uri: obj[:broker][:uri],
                             username: obj[:credentials][:username],
                             password: obj[:credentials][:password])

    unless br.uri
      br.uri = br._make_uri
    end

    br
  end

  def _make_uri
    "mqtts://#{CGI.escape(@username)}:#{CGI.escape(@password)}@#{@host}:#{@port}"
  end
end


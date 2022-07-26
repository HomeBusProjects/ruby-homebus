require 'homebus/broker'

class Homebus::Broker
  attr_accessor :host, :port, :username, :password

  def initialize(**args)
    @host = args[:host] if args[:host]
    @port = args[:port] if args[:port]
    @username = args[:username] if args[:username]
    @password = args[:password] if args[:password]
  end

  def connect!
    unless host && port && username
      abort 'no broker'
    end

    @mqtt = MQTT::Client.connect(host: @host, port: @port, username: @username, password: @password, ssl: :TLSv1_2)
  end

  def configured?
    host && port && username && password
  end

  def connected?
    @mqtt && @mqtt.connected?
  end

  def publish!(id, ddc, msg, timestamp = Time.now.to_i)
    homebus_msg = {
      source: id,
      timestamp: timestamp,
      contents: {
        ddc: ddc,
        payload: msg
      }
    }

    json = JSON.generate(homebus_msg)
    @mqtt.publish "homebus/device/#{id}/#{ddc}", json, true
  end

  def listen!(callback)
    @mqtt.get do |topic, message|
      begin
        parsed = JSON.parse message, symbolize_names: true
      rescue
        raise Homebus::Broker::ReceiveBadJSON
      end

      if parsed[:source].nil? || parsed[:contents].nil?
        raise Homebus::Broker::ReceiveBadEncapsulation
      end

      received_msg = {
        source: parsed[:source],
        timestamp: parsed[:timestamp],
        sequence: parsed[:sequence],
        ddc: parsed[:contents][:ddc],
        payload: parsed[:contents][:payload]
      }

      callback.call(received_msg)
    end
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

    { broker: {
        hostname: host,
        port: port
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
                             username: obj[:credentials][:username],
                             password: obj[:credentials][:password])
  end
end

class Homebus::Broker::ReceiveBadJSON < Exception
end

class Homebus::Broker::ReceiveBadEncapsulation < Exception
end

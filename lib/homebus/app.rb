require 'homebus/homebus'
require 'homebus/provision'
require 'homebus/config'
require 'homebus/state'

require 'json'

class Homebus::App
  attr_reader :options, :quit
  attr_reader :homebus_server, :homebus_port
  attr_accessor :provision_request
  attr_accessor :device, :devices

  def initialize(options)
    @options = options
    @quit = false

    unless @config
      @config = Homebus::Config.new
      @config.load
    end

    unless @state
      @state = Homebus::State.new
      @state.load!
    end

    login = @config.default_login
    unless login
      raise Homebus::App::NoDefaultLogin
    end

    @homebus_server = login[:provision_server]
    @homebus_token = login[:token]
  end

  # define this so that apps that don't need it don't have to define it themselves
  def setup!
  end

  def run!
    setup!

    begin
      @provision_request = Homebus::Provision.from_config @config.local_config
      update_devices(@provision_request)
    rescue Homebus::Provision::InvalidDeserialization
      @provision_request ||= Homebus::Provision.new(name: name,
                                                    homebus_server: @homebus_server,
                                                    consumes: consumes,
                                                    publishes: publishes,
                                                    devices: devices
                                                   )
    end

    unless provisioned?
      while !provision!
        sleep 30
      end
    end

    while !quit
      begin
        broker = @provision_request.broker

        unless broker.configured? && broker.connected?
          broker.connect!

          unless broker.connected?
            sleep(5)
          end
        end

        work!
      rescue => error
        puts "work! exception"
        pp error
        pp @provision_request

        abort
      end
    end
  end

  def provisioned?
    @provision_request && @provision_request.status == :provisioned
  end

  def provision!
    if provisioned?
      return true
    end

    old_status = @provision_request.status

    @provision_request.provision(@homebus_token)

    if old_status != @provision_request.status
      @config.local_config = @provision_request.to_hash
      @config.save_local
    end

    if @provision_request.status == :provisioned
      update_devices(@provision_request)
      return true
    end

    return false
  end

  def _create_provision_request
    Homebus::Provision.from_config
  end

  def update_devices(provision_request = nil)
    @config.local_config[:provision_request][:devices].each do |device|
      matches = devices.select do |d|
          d.name == device[:name] &&
          d.manufacturer == device[:identity][:manufacturer] &&
          d.model == device[:identity][:model] &&
          d.serial_number == device[:identity][:serial_number]
      end

      if matches.length > 1
        raise Homebus::App::TooManyDevicesMatched
      end

      if matches.length == 0
        raise Homebus::App::NoDevicesMatched
      end

      matches[0].id = device[:id]
      matches[0].token = device[:token]
      matches[0].provision = provision_request
    end
  end

  def subscribe!(*ddcs)
    @provision_request.broker.subscribe(ddcs)
  end

  def subscribe_to_sources!(*ids)
    @provision_request.broker.subscribe_to_sources!(ids)
  end

  def subscribe_to_source_ddc!(source, ddc)
    subscribe_to_sources([source])
  end

  def listen!
    @provision_request.broker.listen!(-> (msg) { self.receive!(msg) })
  end

  def devices
    if device
      [ device ]
    else
      [ ]
    end
  end

  def consumes
    []
  end

  def publishes
    []
  end
end

class Homebus::App::NoDefaultLogin < Exception
end

class Homebus::App::TooManyDevicesMatched < Exception
end

class Homebus::App::NoDevicesMatched < Exception
end

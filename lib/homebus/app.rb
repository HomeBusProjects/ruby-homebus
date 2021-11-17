require 'homebus/homebus'
require 'homebus/provision'
require 'homebus/config'

require 'mqtt'
require 'json'

class Homebus::App
  attr_reader :options, :quit
  attr_reader :homebus_server, :homebus_port
  attr_accessor :provision_request
  attr_accessor :device, :devices

  def initialize(options)
    @options = options
    @quit = false
    
    # daemonization will change CWD so expand relative paths now
    options[:logfile] = File.expand_path(logfile) if logfile?
    options[:pidfile] = File.expand_path(pidfile) if pidfile?

    @config = Homebus::Config.new
    @config.load

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
    check_pid
    daemonize if daemonize?
    write_pid
    trap_signals

    if logfile?
      redirect_output
    elsif daemonize?
      suppress_output
    end

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
    @provision_request.broker.listen!(-> (topic, msg) { self.receive_callback(topic, msg) })
  end

  def receive_callback(topic, msg)
    begin
      parsed = JSON.parse msg, symbolize_names: true
    rescue
      next
    end

    if parsed[:source].nil? || parsed[:contents].nil?
      next
    end

    receive!({
               source: parsed[:source],
               timestamp: parsed[:timestamp],
               sequence: parsed[:sequence],
               ddc: parsed[:contents][:ddc],
               payload: parsed[:contents][:payload]
             })
  end

  def daemonize?
    options[:daemonize]
  end

  def config_filename
    options[:config_filename] || '.homebus.json'
  end

  def logfile
    options[:logfile]
  end

  def pidfile
    options[:pidfile]
  end

  def logfile?
    !logfile.nil?
  end

  def pidfile?
    !pidfile.nil?
  end
  
  def trap_signals
    trap(:QUIT) do   # graceful shutdown of run! loop
      @quit = true
    end
  end

  def suppress_output
    $stderr.reopen('/dev/null', 'a')
    $stdout.reopen($stderr)
  end

  def redirect_output
    FileUtils.mkdir_p(File.dirname(logfile), :mode => 0755)
    FileUtils.touch logfile
    File.chmod(0644, logfile)
    $stderr.reopen(logfile, 'a')
    $stdout.reopen($stderr)
    $stdout.sync = $stderr.sync = true
  end

  def daemonize
    exit if fork
    Process.setsid
    exit if fork
    Dir.chdir "/"
  end

  def check_pid
    if pidfile?
      case pid_status(pidfile)
      when :running, :not_owned
        puts "A server is already running. Check #{pidfile}"
        exit(1)
      when :dead
        File.delete(pidfile)
      end
    end
  end

  def pid_status(pidfile)
    return :exited unless File.exists?(pidfile)
    pid = ::File.read(pidfile).to_i
    return :dead if pid == 0
    Process.kill(0, pid)      # check process status
    :running
  rescue Errno::ESRCH
    :dead
  rescue Errno::EPERM
    :not_owned
  end

  def write_pid
    if pidfile?
      begin
        File.open(pidfile, ::File::CREAT | ::File::EXCL | ::File::WRONLY){|f| f.write("#{Process.pid}") }
        at_exit { File.delete(pidfile) if File.exists?(pidfile) }
      rescue Errno::EEXIST
        check_pid
        retry
      end
    end
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

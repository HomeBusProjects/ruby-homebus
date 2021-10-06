require 'homebus/homebus'
require 'homebus/provision'
require 'homebus/config'

require 'mqtt'
require 'json'

class Homebus::App
  attr_reader :options, :quit
  attr_reader :homebus_server, :homebus_port
  attr_reader :broker_uri
  
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

    while !provision!
      sleep 30
    end

    while !quit
      begin
        work!
      rescue => error
        puts "work! exception"
        pp error

        unless @mqtt.connected?
          connect!

          unless @mqtt.connected?
            sleep(5)
          end
        end
      end
    end
  end

  def connect!
    puts @broker_uri
    @mqtt = MQTT::Client.connect(@broker_uri)
  end

  def provision!
    if @broker_uri
      connect!
      return true
    end

    provision_request = Homebus::Provision.new(name: self.name,
                                               homebus_server: @homebus_server,
                                               consumes: consumes,
                                               publishes: publishes,
                                               devices: devices
                                              )

    provision_request.provision!(@homebus_token)

    @config.local_config[:provision_request] = provision_request.to_hash
    @config.save_local

    @broker_uri = provision_request.broker_uri

    connect!

    true
  end

  def publish!(ddc, msg)
    publish_to! @uuid, ddc, msg
  end

  def publish_to!(uuid, ddc, msg)
    homebus_msg = {
      source: uuid,
      timestamp: Time.now.to_i,
      contents: {
        ddc: ddc,
        payload: msg
      }
    }

    json = JSON.generate(homebus_msg)
    if @mqtt_broker && @mqtt_port && @mqtt_username && @mqtt_password
      @mqtt.publish "homebus/device/#{@uuid}/#{ddc}", json, true
    else
      
    end
  end

  def subscribe!(*ddcs)
    ddcs.each do |ddc| @mqtt.subscribe 'homebus/device/+/' + ddc end
  end

  def subscribe_to_sources!(*uuids)
    uuids.each do |uuid|
      topic =  'homebus/device/' + uuid
      @mqtt.subscribe topic
    end
  end

  def subscribe_to_source_ddc!(source, ddc)
    topic =  'homebus/device/' + source + '/' + ddc
    @mqtt.subscribe topic
  end

  def listen!
    @mqtt.get do |topic, msg|
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
end

class Homebus::App::NoDefaultLogin < Exception
end

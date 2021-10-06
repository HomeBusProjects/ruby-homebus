require 'homebus/homebus'

class Homebus::Config
  attr_accessor :login_config_filename, :local_config_filename
  attr_accessor :login_config, :local_config

  DEFAULT_LOGIN_CONFIG_FILENAME = ".homebus-config.json"
  DEFAULT_LOCAL_CONFIG_FILENAME = ".homebus.json"

  def initialize
    @login_config_filename = File.join(ENV['HOME'], DEFAULT_LOGIN_CONFIG_FILENAME)
    @local_config_filename = DEFAULT_LOCAL_CONFIG_FILENAME

    @login_config = { default: nil, next_index: 0, homebus_instances: [] }
    @local_config = {}
  end

  def load
    load_login
    load_local
  end

  def save
    save_login
    save_local
  end

  def default_login
    unless @login_config[:default_login]
      pp @login_config

      raise Homebus::Config::NoDefaultLogin
    end

    @login_config[:homebus_instances].select { |login| login[:index] == login_config[:default_login] }.first
  end

  def remove_default_login
    login_config[:logins].select! { |login| login[:index] != login_config[:default_login] }
  end

  def load_login
    unless File.exists? @login_config_filename
      return @login_config
    end

    @login_config = JSON.parse(File.read(@login_config_filename), symbolize_names: true)
  end

  def load_local
    unless File.exists? @local_config_filename
      return {}
    end

    @local_config = JSON.parse(File.read(@local_config_filename), symbolize_names: true)
  end

  def save_login
    File.open(@login_config_filename, 'w') do |f|
      f.puts JSON.pretty_generate(@login_config)
    end

    FileUtils.chmod(0600, @login_config_filename)
  end

  def save_local
    File.open(@local_config_filename, 'w') do |f|
      f.puts JSON.pretty_generate(@local_config)
    end

    FileUtils.chmod(0600, @local_config_filename)
  end
end

class Homebus::Config::NoDefaultLogin < Exception
  "No default login"
end

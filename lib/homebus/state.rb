require 'fileutils'
require 'json'

class Homebus::State
  attr_accessor :store, :filename

  DEFAULT_STATE_FILENAME = '.homebus-state.json'

  def initialize
    @store = {}
    @filename = DEFAULT_STATE_FILENAME

    load!
  end

  def clear!
    @state = {}
  end

  def load!
      @store = JSON.parse(File.read(@filename), symbolize_names: true)
  end

  def load
    begin
      load!
      return true
    rescue
      return false
    end
  end

  def commit!
      File.write(@filename, JSON.pretty_generate(@store))
      FileUtils.chmod(0600, @login_config_filename)
  end

  def commit
    begin
      commit!
      return true
    rescue
      return false
    end
  end
end

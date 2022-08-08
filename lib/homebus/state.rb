require 'fileutils'
require 'json'

class Homebus::State
  attr_accessor :state, :filename

  DEFAULT_STATE_FILENAME = '.homebus-state.json'

  def initialize
    @state = {}
    @filename = DEFAULT_STATE_FILENAME

    if File.exist? @filename
      load!
    else
      commit!
    end
  end

  def clear!
    @state = {}
  end

  def load!
    if File.exists? @filename
      @state = JSON.parse(File.read(@filename), symbolize_names: true)
    end
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
      File.write(@filename, JSON.pretty_generate(@state))
      FileUtils.chmod(0600, @filename)
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

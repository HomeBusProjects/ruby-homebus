require 'homebus/homebus'

require 'optparse'

# based on Jake Gordon's excellent article, "Daemonizing Ruby Processes"
# https://codeincomplete.com/posts/ruby-daemons/

class Homebus::Options
  attr_reader :options

  def initialize
    @options        = {}

    config_file_help = 'the configuration file name (default: .homebus.json)'
    daemonize_help = 'run daemonized in the background (default: false)'
    pidfile_help   = 'the pid filename'
    logfile_help   = 'the log filename'
    include_help   = 'an additional $LOAD_PATH'
    debug_help     = 'set $DEBUG to true'
    warn_help      = 'enable warnings'
    homebus_help   = 'specify HomeBus provisioner name or IP address'
    homebus_port_help   = 'specify HomeBus server port number'
    homebus_auth_token_help   = 'specify HomeBus server auth token'

    op = OptionParser.new
    op.banner =  banner
    op.separator ''
    op.separator "Usage: #{name} [@options]"
    op.separator ''

    app_options(op)

    op.separator 'Process options:'
    op.on('-c', '--config',   config_file_help)  {         @options[:config_filename] = true  }
    op.on('-d', '--daemonize',   daemonize_help) {         @options[:daemonize] = true  }
    op.on('-p', '--pid PIDFILE', pidfile_help)   { |value| @options[:pidfile]   = value }
    op.on('-l', '--log LOGFILE', logfile_help)   { |value| @options[:logfile]   = value }
    op.separator ''

    op.separator "HomeBus options"
    op.on("-b", "--homebus HOMEBUS_SERVER", homebus_help) { |value| options[:homebus_server] = value; }
    op.on("-P", "--homebus-port HOMEBUS_PORT", homebus_port_help) { |value| options[:homebus_port] = value; }
    op.on("-a", "--homebus-auth-token HOMEBUS_AUTH_TOKEN", homebus_auth_token_help) { |value| options[:homebus_auth_token] = value; }
    op.separator ''

    op.separator 'Ruby options:'
    op.on('-I', '--include PATH', include_help) { |value| $LOAD_PATH.unshift(*value.split(':').map{|v| File.expand_path(v)}) }
    op.on(      '--debug',        debug_help)   { $DEBUG = true }
    op.on(      '--warn',         warn_help)    { $-w = true    }
    op.separator ''

    op.separator 'Common options:'
    op.on('-h', '--help')    { puts op.to_s; exit }
    op.on('-v', '--version') { puts version; exit }
    op.on('-V', '--verbose') { options[:verbose] = true; }
    op.separator ''

    op.parse!(ARGV)
  end

  def banner
    'An example of how to daemonize a long running Ruby process.'
  end

  def name
    'HomeBusApp'
  end

  def version
    '0.0.1'
  end

  def app_options(op)
  end
end

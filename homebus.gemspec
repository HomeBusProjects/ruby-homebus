Gem::Specification.new do |s|
  s.name        = 'homebus'
  s.version     = '0.10.13'
  s.licenses    = ['MIT']
  s.summary     = 'Ruby interface to HomeBus'
  s.description = 'Ruby interface to the HomeBus MQTT automatic provisioner'
  s.authors     = ['John Romkey']
  s.email       = 'romkey+ruby@romkey.com'
  s.files       = ['lib/homebus.rb', 'lib/homebus/homebus.rb', 'lib/homebus/app.rb', 'lib/homebus/config.rb', 'lib/homebus/device.rb', 'lib/homebus/provision.rb', 'lib/homebus/options.rb' ]
  s.add_runtime_dependency 'mqtt', '~> 0.5.0'
  s.homepage    = 'https://homebus.org/'
  s.metadata    = { 'source_code_uri' => 'https://github.com/romkey/ruby-homebus' }
end

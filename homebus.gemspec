#!/usr/bin/env ruby -rubygems

require_relative "lib/homebus/version"

Gem::Specification.new do |s|
  s.name        = 'homebus'
  s.version     = Homebus::VERSION
  s.licenses    = ['MIT']
  s.summary     = 'Ruby interface to Homebus'
  s.description = 'Ruby interface to the Homebus MQTT automatic provisioner'
  s.authors     = ['John Romkey']
  s.email       = 'romkey+ruby@romkey.com'
  s.files       = ['lib/homebus.rb', 'lib/homebus/homebus.rb', 'lib/homebus/app.rb', 'lib/homebus/config.rb', 'lib/homebus/device.rb', 'lib/homebus/provision.rb', 'lib/homebus/options.rb', 'lib/homebus/state.rb' ]
  s.homepage    = 'https://homebus.org/'
  s.metadata    = { 'source_code_uri' => 'https://github.com/romkey/ruby-homebus' }

  s.add_runtime_dependency 'paho-mqtt', '~> 1.0.12'
end

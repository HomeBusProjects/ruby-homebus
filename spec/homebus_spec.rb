require 'spec_helper'

require 'homebus'

class TestHomebusApp < Homebus::App
  # override config so that the superclasses don't try to load it during testing
  def initialize(options)
    @config = Hash.new
    @config = Homebus::Config.new

    @config.login_config = {
                            "default_login": 0,
                            "next_index": 1,
                            "homebus_instances": [
                                      {
                                        "provision_server": "https://homebus.org",
                                       "email_address": "example@example.com",
                                       "token": "XXXXXXXXXXXXXXXX",
                                       "index": 0
                                      }
                                    ]
    }

    @store = Hash.new
    super
  end
end

describe Homebus do
  context "Version number" do
    it "Has a version number" do
      expect(Homebus::VERSION).not_to be_nil
      expect(Homebus::VERSION.class).to be String
    end
  end 
end


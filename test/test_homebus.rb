require 'minitest/autorun'
require 'homebus'

class HomebusTest < Minitest::Test
  def test_homebus
    hb = Homebus.new(homebus_server: 'http://localhost:3000')
  end
end

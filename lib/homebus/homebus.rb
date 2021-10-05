require 'net/http'
require 'uri'
require 'json'

class Homebus
  attr_accessor :homebus_server

  def initialize(**args)
    @homebus_server = args[:homebus_server]
  end

  # login and get a token good for creating provision_requests
  def login(email_address, password)
    url = "#{@homebus_server}/api/auth"
    uri = URI(url)

    data = { email_address: email_address,
            password: password,
            name: 'ruby-homebus'
           }

    req = Net::HTTP::Post.new(uri)

    req['Content-type'] = 'application/json'
    req.body = data.to_json

    res = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end

    if res.code == '200'
      body = JSON.parse(res.body)
      if body['token']
        return body['token']
      end
    end
  end

  def logout(token)
    url = "#{@hombus_server}/api/token/#{token}"
    uri = URI(url)

    req = Net::HTTP::Delete.new(uri)

    if token
      req['Authorization'] = 'Bearer ' + token
    end

    res = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
  end
end

 require "uri"
 require 'json'
 require 'net/http'
 require 'net/https'
 require 'base64'

class FMI
  
  URL  = "fmipmobile.icloud.com"
  PORT = 443
  
  def initialize(user, pass, debug=false)
    
    @user = user
    @debug = debug
    @devices = nil

    @defaultClientContext = {
      'clientContext' => {
        'appName'        => 'FindMyiPhone',
        'appVersion'     => '1.4',
        'buildVersion'   => '145',
        'deviceUDID'     => '0000000000000000000000000000000000000000',
        'inactiveTime'   => 5911,
        'osVersion'      => '4.2.1',
        'personID'       => 0,
        'productType'    => 'iPad1,1'
      }
    }

    @defaultServerContext = {
      'serverContext' => {
           "callbackIntervalInMS" => 3000,
           "clientId" => "0000000000000000000000000000000000000000",
           "deviceLoadStatus" => "203",
           "hasDevices" => true,
           "lastSessionExtensionTime" => nil,
           "maxDeviceLoadTime" => 60000,
           "maxLocatingTime" => 90000,
           "preferredLanguage" => "en",
           "prefsUpdateTime" => 1276872996660,
           "sessionLifespan" => 900000,
           "timezone" => {
               "currentOffset" => -25200000,
               "previousOffset" => -28800000,
               "previousTransition" => 1268560799999,
               "tzCurrentName" => "Pacific Daylight Time",
               "tzName" => "America/Los_Angeles"
           },
           "validRegion" => true
       },
    }
    
		auth = Base64.encode64(user+':'+pass)
    @headers = {
      'Content-Type' => 'application/json; charset=utf-8',
      'X-Apple-Find-Api-Ver' => '2.0',
      'X-Apple-Authscheme' => 'UserIdGuest',
      'X-Apple-Realm-Support' => '1.2',
      'User-Agent' => 'Find iPhone/1.4 MeKit (iPad: iPhone OS/4.2.1)',
      'X-Client-Name' => 'iPad',
      'X-Client-Uuid' => '0cf3dc501ff812adb0b202baed4f37274b210853',
      'Accept-Language' => 'en-us',
      'Authorization' => "Basic #{auth}"
    }

    # mgb: discover our partition
    @http = Net::HTTP.new(URL, PORT)
    @http.use_ssl = true
    partition = @http.post("/fmipservice/device/#{@user}/initClient", JSON.generate(@defaultClientContext), @headers)
    @http = Net::HTTP.new(partition['X-Apple-MMe-Host'], PORT)
    @http.use_ssl = true

  end
  
  def devices
    update if @devices.nil?
    @devices
  end
  
  def sendMessage(device_num=0, subject="Find My iPhone Alert", msg="Where am I and who are you?", alarm=true)
    ctx = createDeviceContext(device_num)
    ctx['sound'] = alarm
    ctx['subject'] = subject
    ctx['text'] = msg
    ctx['userText'] = true
    post("/fmipservice/device/#{@user}/sendMessage", ctx)
  end
  
  def locate(device_num=0, max_wait=300)
    start = Time.now
    begin
      raise "Unable to find location within '#{max_wait}' seconds" if ((Time.now - start) > max_wait)
      sleep(5)
      update
      raise "Invalid device number!" if @devices[device_num].nil?  
      raise "There is no location data for this device (#{@devices[device_num]['name']})" if @devices[device_num]['location'].nil?
    end while @devices[device_num]['location']['locationFinished'] == 'false'
    {
      :name          => @devices[device_num]['name'],
      :latitude      => @devices[device_num]['location']['latitude'],
      :longitude     => @devices[device_num]['location']['longitude'],
      :accuracy      => @devices[device_num]['location']['horizontalAccuracy'],
      :timestamp     => @devices[device_num]['location']['timeStamp'],
      :position_type => @devices[device_num]['location']['positionType']
    }
  end

private

  def createDeviceContext(device_num=0)
    ctx = @defaultClientContext.merge @defaultServerContext # implicit cloning
    ctx['clientContext']['selectedDevice'] = @devices[device_num]['id']
    ctx['clientContext']['shouldLocate'] = false
    ctx['device'] = @devices[device_num]['id']
    ctx
  end
  
  def update
    json = post("/fmipservice/device/#{@user}/initClient", @defaultClientContext)
    @devices = [];
    json['content'].each { |device| @devices << device }
  end
  
  def post(path, data)
    JSON.parse(fetch(path, JSON.generate(data), @headers).body)
  end
  
  def fetch(path, data, headers, limit=10)
    raise ArgumentError, 'HTTP redirect too deep' if limit == 0
    response = @http.post(path, data, headers)
    case response
    when Net::HTTPSuccess     then response
    when Net::HTTPRedirection then fetch(response['location'], data, headers, limit - 1)
    else
      response.error!
    end
  end

  def debug(text)
    puts "[Debug - Find My iPhone] - #{text}" if $debug
  end

end
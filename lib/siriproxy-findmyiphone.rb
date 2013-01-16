require 'cora'
require 'siri_objects'
require 'timeout'
require_relative 'fmi'

class SiriProxy::Plugin::FindMyIPhone < SiriProxy::Plugin
  
  def initialize(config)
    @credentials = config['iphones'] || {}
    
    @wait_msg = config['wait_msg'] || "Please wait while I try to find %s."
    @ok_msg   = config['ok_msg']   || "Ok. I found %s."
    @err_msg  = config['err_msg']  || "I'm sorry but I could not find %s."
    
    # mgb: we must build a alias => name index
    @aliases = {}
    @credentials.each do |name,creds| 
      creds['aliases'] ||= []
      # delete returns the value
      (creds.delete 'aliases').each { |a| @aliases[a] = name }
    end
  end

  listen_for /find (.* (?:iphone|ipad))/i do |iphone_name|
    device_name = scrub(iphone_name)
    device_name = @aliases[device_name] || device_name
    auth = @credentials[device_name]
    # mgb: have siri say 'your iphone' when you ask about 'my iphone' :)
    iphone_name = iphone_name.gsub('my', 'your')
    if auth
      say @wait_msg % iphone_name
      Thread.new {
        begin
          Timeout::timeout(30) do
            fmi = FMI.new(auth['username'], auth['password'])
            device_num = nil            
            fmi.devices.each_with_index { |device, num| device_num = num if scrub(device['name']) == device_name }
            if device_num
              device = fmi.devices[device_num]
              log "Found Device ##{device_num} = #{device['name']}"
              fmi.sendMessage(device_num)
            end
            say target ? @ok_msg % iphone_name : @err_msg % iphone_name 
            request_completed
          end
        rescue Timeout::Error
           say @err_msg % iphone_name
           request_completed
        end
      }
    else
      say @err_msg % iphone_name
      request_completed
    end

  end

private
  
  def log(text)
    puts "[Info - Find My iPhone] #{text}" if $LOG_LEVEL >= 1
  end
  
  def scrub(text)
    if text
      return text.strip.downcase.tr('"\'','')
    end
    return ''
  end
  
end  

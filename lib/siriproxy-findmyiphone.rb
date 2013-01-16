require 'cora'
require 'siri_objects'
require 'timeout'
require_relative 'fmi'

class SiriProxy::Plugin::FindMyIPhone < SiriProxy::Plugin
  
  def initialize(config)
    @iphones = config['iphones'] || {}
  end

  listen_for /find (.* iphone)/i do |iphone|
    name = scrub iphone
    iphone = iphone.gsub('my', 'your')    
    if @iphones[name]
      say "Please wait while I try to find #{iphone}."
      username = @iphones[name]['username']
      password = @iphones[name]['password']
      name = @iphones[name]['device'] || name
      Thread.new {
        begin
          Timeout::timeout(30) do
            fmi = FMI.new(username, password)
            target = nil            
            fmi.devices.each_with_index { |device, num| target = num if scrub(device['name']) == name }
            if target
              device = fmi.devices[target]
              log "Found Target Device #{target} = #{device['name']}"
              fmi.sendMessage(target)
            end
            say target ? "Ok. I found #{iphone}." : "I'm sorry but I could not find #{iphone}." 
            request_completed
          end
        rescue Timeout::Error
           say "I'm sorry but I could not find #{iphone}."
           request_completed
        end
      }
    else
      say "I'm sorry but I could not find #{iphone}"
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

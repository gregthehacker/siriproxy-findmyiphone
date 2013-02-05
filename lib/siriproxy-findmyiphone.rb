require 'cora'
require 'siri_objects'
require 'timeout'
require_relative 'fmi'

class SiriProxy::Plugin::FindMyIPhone < SiriProxy::Plugin
  
  def initialize(config)
    @credentials = config['iphones'] || {}
    
    @text = config['text'] || "Where am I and who are you?"
  
    @wait_msg = config['wait_msg'] || "Please wait while I try to find %s."
    @ok_msg   = config['ok_msg']   || "Ok. I found %s."
    @err_msg  = config['err_msg']  || "I'm sorry but I could not find %s."
    
    # mgb: we must build a alias => name index
    @aliases = {}
    @credentials.each do |name,creds| 
      creds['aliases'] ||= []
      creds['aliases'].each { |a| @aliases[a] = name }
    end
  end

  listen_for /where(?:'s| is) (.* (?:iphone|ipad))/i do |iphone_name|
    log "Trying to find '#{iphone_name}'..."
    device_name = scrub(iphone_name)
    device_name = @aliases[device_name] || device_name
    auth = @credentials[device_name]
    # mgb: have siri say 'your iphone' when you ask about 'my iphone' :)
    iphone_name = iphone_name.gsub('my', 'your')
    if auth
      log "Logging in with username = '#{auth['username']}'"
      say @wait_msg % iphone_name
      Thread.new {
        begin
          Timeout::timeout(60) do
            fmi = FMI.new(auth['username'], auth['password'])
            device_num = nil            
            fmi.devices.each_with_index { |device, num| device_num = num if scrub(device['name']) == device_name }
            add_views = nil
            if device_num
              loc = fmi.locate(device_num, 60)
              log "Found device ##{device_num} = #{fmi.devices[device_num]['name']} @ #{loc[:latitude]},#{loc[:longitude]}"
              #def initialize(label="Apple", street="1 Infinite Loop", city="Cupertino", stateCode="CA", countryCode="US", postalCode="95014", latitude=37.3317031860352, longitude=-122.030089795589)
              add_views = SiriAddViews.new
              add_views.make_root(last_ref_id)
              map_snippet = SiriMapItemSnippet.new
              map_snippet.items << SiriMapItem.new
              map_snippet.items[0].label = loc[:name]
              map_snippet.items[0].location = SiriLocation.new(loc[:name], "", "", "", "", "", loc[:latitude], loc[:longitude])
              utterance = SiriAssistantUtteranceView.new(@ok_msg % iphone_name)
              add_views.views << utterance
              add_views.views << map_snippet  
            else
              log "Could not find device # for '#{iphone_name}'"            
            end
            if add_views
              send_object add_views
            else 
              say @err_msg % iphone_name 
            end
            request_completed
          end
        rescue Timeout::Error
           say @err_msg % iphone_name
           request_completed
        end
      }
    else
      log "No auth for '#{iphone_name}'"
      say @err_msg % iphone_name
      request_completed
    end
  end

  listen_for /find (.* (?:iphone|ipad))/i do |iphone_name|
    log "Trying to find '#{iphone_name}'..."
    device_name = scrub(iphone_name)
    device_name = @aliases[device_name] || device_name
    auth = @credentials[device_name]
    # mgb: have siri say 'your iphone' when you ask about 'my iphone' :)
    iphone_name = iphone_name.gsub('my', 'your')
    if auth
      log "Logging in with username = '#{auth['username']}'"
      say @wait_msg % iphone_name
      Thread.new {
        begin
          Timeout::timeout(30) do
            fmi = FMI.new(auth['username'], auth['password'])
            device_num = nil            
            fmi.devices.each_with_index { |device, num| device_num = num if scrub(device['name']) == device_name }
            if device_num
              device = fmi.devices[device_num]
              log "Found device ##{device_num} = #{device['name']}"
              # mgb: change the subject based on device
              type = device_name =~ /iphone$/ ? 'iPhone' : 'iPad'
              fmi.sendMessage(device_num, "Find My #{type} Alert", @text)
            else
              log "Could not find device # for '#{iphone_name}'"
            end
            say device_num ? @ok_msg % iphone_name : @err_msg % iphone_name 
            request_completed
          end
        rescue Timeout::Error
           say @err_msg % iphone_name
           request_completed
        end
      }
    else
      log "No auth for '#{iphone_name}'"
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

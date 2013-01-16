siriproxy-findmyiphone
======================

## About
___

This is a [Find My iPhone](http://www.apple.com/icloud/features/find-my-iphone.html) plugin for [Siri Proxy](https://github.com/plamoni/SiriProxy). It gives you the ability to say (something like) *"Find my wife's iPhone"* and Siri will trigger a "Play Sound" action on the device just as you would do in the [iCloud web interface](https://www.icloud.com/).

This becomes very handy as the sound plays at high volume no matter if the iPhone is in silent mode. This has proven very useful in my home where I am constantly asked "Can you call my phone?" as my wife desperately searches for her iPhone which is usually in silent mode.

## Installation
___

You need to copy the following snippet and paste it in your `~/.siriproxy/config.yml`

	  - name: 'FindMyIPhone'
	    git: 'git://github.com/mgbowman/siriproxy-findmyiphone.git'
	    iphones:	    
	    	my wifes iphone:
	    		username: 'id@apple.com'
	    		password: 'password'
	    		# optional
				device: 'lauras iphone'

This allows you to say *"Find my wife's iPhone"* and it will look for a device named "Laura's iPhone"

**Note** that cases and quotes are ignored - `wife's iPhone == wifes iphone` and `Laura's iPhone == lauras iphone`

## Credits

Most of Find My iPhone Ruby implementation is credited to <a href="https://github.com/hpop/rosumi" target="_blank">hpop's rosumi</a>.
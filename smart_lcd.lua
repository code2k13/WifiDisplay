--- dont forget to change this---
mqtt_ip = "ip"
mqtt_port = 19287
mqtt_usr = "user"
mqtt_pwd = "pwd"
wifi_nwid = "ssid"
wifi_pwd ="wifipwd"
---------------------------------
msg = ""
msg_len = 0
msg_ln_ct = 5
ypos = 0
curr_ln = 0
msg_type = " "
wait_dur = 0
iscon = false
name = "SmartDisplay"
isNewImg = true
ctr = 0
topics = {"IMG","TXT"}
 
function init_i2c_display()
     i2c.setup(0, 4, 3, i2c.SLOW) 
     disp = u8g.ssd1306_128x64_i2c(0x3c)
     disp:setFont(u8g.font_6x10) 
end

function get_line(l)
	if l > -1 and l < 6  then
		return "          "
	end
	l = l - 6	 
 	return string.sub(msg, (l*20)+1,(l+1)*20)
end

function drawText()	
    for i=1,7 do      
      disp:drawStr( 0, (i*10) + ypos,get_line(i-1 + curr_ln)) 
    end 	  
end

function drawImage()
	disp:drawBitmap(16,0,12,64,msg)
end

function drawNewMessage()
  disp:drawStr( 0, 20, "New Message!") 
  disp:drawBox(20,25,80,30)
  disp:setColorIndex(0)
  disp:drawLine(20, 25, 60, 35)
  disp:drawLine(60, 35, 100, 25)
  disp:setColorIndex(1)
end

function drawloop1()		  
          disp:firstPage()
          repeat
               drawText()
          until disp:nextPage() == false       
end

function drawloop2()		  
          disp:firstPage()
          repeat
               drawImage()
          until disp:nextPage() == false       
end

function drawloop3()		  
          disp:firstPage()
          repeat
               drawNewMessage()
          until disp:nextPage() == false       
end

function setmessage(txt, type)
	msg = txt
	msg_len = string.len(txt)
	msg_ln_ct = math.floor((msg_len/20))+7 
	ypos = 0
	if msg_ln_ct < 13 then
		curr_ln = 6
	else
		curr_ln  = 0
	end	
	msg_type = type
	isNewImg = true
end

function scroll()
	if msg_ln_ct < 13 then
		curr_ln = 6
		return
	end

	if ypos < -9 then
		ypos = 0
			if curr_ln >= msg_ln_ct then
				curr_ln = 0
			else
				curr_ln = curr_ln + 1
			end
	else
		ypos = ypos - 1
	end
end
 
 function updateUI()
 	if wait_dur > 0 then
 		wait_dur = wait_dur -1	
 	    drawloop3()
 	    return  	
 	end
	
 	if msg_type == 'IMG' and isNewImg == true then
 		drawloop2()
 		isNewImg = false
 	end

 	if msg_type == 'TXT' then
		drawloop1()
		scroll()
 	end
 end

function show_sys_msg(m)	
    setmessage(m , 'TXT')
end

m = mqtt.Client(name, 120, mqtt_usr, mqtt_pwd)
m:lwt("/lwt", "offline", 0, 0)
m:on("offline", function(con) 
	iscon = false
	show_sys_msg("> Offline.Retrying")  
	end)

m:on("message", function(conn, topic, data) 
	print(topic,type(data))
	wait_dur = 5  
	setmessage(data , topic)	
	m:publish('ACK', name, 0, 0)
end)		

function checkConnection()
		if wifi.sta.getip() ~= nil then  			
        	if iscon == false then   	
        		show_sys_msg('> Connected to Wifi.> Connecting to     internet...')	 
				m:connect(mqtt_ip, mqtt_port, 0, function(conn) 
					show_sys_msg('> Connected')
					m:subscribe({["IMG"] = 0, ["TXT"] = 0}, function(conn) 
						show_sys_msg('> Waiting for msg!') 
						iscon = true
						end) 					
					end)
			end
       else
       	    iscon = false
          	show_sys_msg('> Wifi error.       > Retrying') 
          	wifi.sta.connect()         	 
       end
end

function run()
	ctr = ctr + 1
	if ctr > 10 then
		ctr = 0
   		checkConnection()
   end
   	 	updateUI()
end

init_i2c_display()
show_sys_msg('> Booting..') 
wifi.setmode(wifi.STATION)
wifi.sta.config(wifi_nwid, wifi_pwd)
wifi.sta.connect()
tmr.alarm(0, 400, 1, function()  run() end ) 
--[[
Name	: ircbot.lua -- fast, diverse irc bot in lua
Author	: David Shaw (dshaw@redspin.com)
Date	: August 8, 2010
Desc.	: ircbot.lua uses the luasocket library. This
	  can be installed on Debian-based OS's with
	  sudo apt-get install liblua5.1-socket2.
	
License	: BSD License
Copyright (c) 2010, David Shaw
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
* Neither the name of the <ORGANIZATION> nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

]]--

socket = require("socket")
http = require("socket.http")
lineregex = "[^\r\n]+"
verbose = false
mynick = foo

function deliver(s, content)
	s:send(content .. "\r\n\r\n")
end

function msg(s, channel, content)
	deliver(s, "PRIVMSG " .. channel .. " :" .. content)
end

function repspace(main, first, second)
	-- start with 0 --> first instance to replace
	local relapsed = string.sub(main, 1, string.find(main, first) -1 ) 
	
	local temp = string.sub(main, string.find(main, first) + #first)
	relapsed = relapsed .. second .. temp
	
	while string.find(relapsed, first) do
		temp = string.sub(relapsed, string.find(relapsed, first) + #first)
		relapsed = string.sub(relapsed, 1, string.find(relapsed, first) -1 )
		
		relapsed = relapsed .. second .. temp
	end
	
	return relapsed
end

function getpage(_url)
	local page = {}
	local page, status = http.request {
		url = _url,
		method = 'HEAD'
	}
	if verbose then
		print(page, status)
	end
	return page
end

-- process needs to process "line" and call higher bot tasks
function process(s, channel, lnick, line)
	if line:find("help") then
		local com = {}
		com[#com + 1] = "--- Help and Usage ---"
		com[#com + 1] = "google <query> -- returns a Google search - FIXME"
		com[#com + 1] = "so <query> -- returns a Stack Overflow search - FIXME"
		com[#com + 1] = "uptime -- returns the server uptime"
		com[#com + 1] = "die -- kill me (if you can)"
		for x=1, #com do
			msg(s, channel, com[x])
		end
	elseif line:find("die") then
		if lnick == "ezequielg" then
			os.exit()
		else
			msg(s, channel, "you wish!")
		end
	elseif line:find("uptime") then
		local f = io.popen("uptime")
		msg(s, channel, lnick .. ":" .. f:read("*l"))
	-- FIXME
	elseif false and line:find("so ") then
		pr = line:sub((line:find('so')+4), #line)
		local page = ''
		if pr:find(' ') then
			page = getpage('http://www.stackoverflow.com/search?q=' .. repspace(pr, ' ', '+'))
		else
			page = getpage('http://www.stackoverflow.com/search?q=' .. pr)
		end

		for l in page:gmatch(lineregex) do
			if l:find('h3') then
				local so = l:sub((l:find('h3')+12), #l)
				local st = so:sub(1, (so:find('"')-1))
				msg(s, channel, '[StackOverflow] http://stackoverflow.com' .. st)
				return
			end
		end
	elseif false and line:find("google") then
		-- find the query
		-- !! function findparam(line, functionname)   VVVVVVVVVVVVVVVVVV
		local query = string.sub(line, (string.find(line, "google") + 8))
		if query:find(' ') then query = repspace(query, ' ', '+') end
		local page = getpage('http://www.google.com/search?q=define%3A' .. query)
		for line in string.gmatch(page, lineregex) do
			if string.find(line, "disc") then
				local answer = string.sub(line, (string.find(line, "disc") + 20) )
				local ret = string.sub(answer, 1, (string.find(answer, "<")-1))
				if ret:find("&quot;") then 
					ret = repspace(ret, "&quot;", '"')
				end
				msg(s, channel, ret)
			end
		end
	elseif false and line:find("http://") then
		local request = string.sub(line, string.find(line, "http://"), #line)
		if string.find(request, " ") then 
			request = string.sub(request, 1, (string.find(request, " ")-1))
		end
		
		local page = getpage(request)
		if page == nil then
		  msg(s, channel, "I'm being a responsible bot and reporting an error!")
		else
		  for lin in string.gmatch(page, lineregex) do
			if string.find(lin, "<title>") then

				if #lin < string.find(lin, "<title>")+8 then
		
				else
					if lin:find("<title>") and lin:find("</title>") then
					local title = string.sub(lin, (string.find(lin, "<title>")+7), (string.find(lin, "</title")-1))
					msg(s, channel, title)
					end
				end -- !! TODO: add support for "youtube-stye" <title> scheme (nextline)
			end
		  end
		end
	end
end

function pre_process(receive, channel)
	-- gotta grab the ping "sequence".
	if receive:find("PING :") then
		deliver(s, "PONG :" .. string.sub(receive, (string.find(receive, "PING :") + 6)))
		if verbose then
			print("[+] sent server pong")
		end
	elseif receive:find("JOIN") then
		if receive:find(channel .. " :") then
			line = string.sub(receive, (string.find(receive, channel .. " :") + (#channel) + 2))
		end
		if receive:find(":") and receive:find("!") then
			lnick = string.sub(receive, (string.find(receive, ":")+1), (string.find(receive, "!")-1))
		end

		if channel == "#vanguardiasur" and (string.find(lnick, "lozano") or string.find(lnick, "walter")) then
			msg(s, channel, "Hola Walter! El nivel de alegría es " .. math.random() * 100)
		elseif lnick ~= mynick then
			msg(s, channel, "Hola " .. lnick .. "!")
		end

	elseif receive:find("PRIVMSG") then
			if false and verbose then
				msg(s, channel, receive)
			end
			if receive:find(channel .. " :") then
				line = string.sub(receive, (string.find(receive, channel .. " :") + (#channel) + 2))
			end
			if receive:find(":") and receive:find("!") then
				lnick = string.sub(receive, (string.find(receive, ":")+1), (string.find(receive, "!")-1))
			end
			if line then
				process(s, channel, lnick, line)
			end
	end
end

function main(arg)
	local serv = arg[1]
	local password = arg[2]
	local nick = arg[3]
	local channel = "#" .. arg[4]
	local chan_pass = arg[5]

	print("[+] setting up socket to " .. serv)
	s = socket.tcp()
	s:connect(socket.dns.toip(serv), 6667)

	print("[+] authenticating ")
	deliver(s, "PASS " .. password)

	print("[+] trying nick", nick)
	deliver(s, "NICK " .. nick)
	deliver(s, "USER " .. nick .. " " .. " " .. nick .. " " ..  nick .. " " .. ":" .. nick)

	print("[+] joining " .. channel)
	if chan_pass then
		deliver(s, "JOIN " .. channel .. " " .. chan_pass)
	else
		deliver(s, "JOIN " .. channel)
	end

	mynick = nick
	while true do
		local rcv, err = s:receive('*l')
		if not rcv then
			print("[oops] error: " .. err)
			if err == "closed" then
				return
			end
		else
			pre_process(rcv, channel)
		end
		if verbose then print(rcv) end
	end
end

-- I ain't gonna stop writing C if I can
while true do
	main(arg)
end

--[[
    Turtle Control OS
    Originally created by ottomated, modified by PrintedScript, Improved by LostGameDev
    https://github.com/PrintedScript/turtle-control
]]
-- Settings
local ConnectionStatus = false
local FailedToConnectAmount = 0
local WebSocketFilePastebinID = "TUc9nU5i"
local WebsocketServer = ""

-- JSON LIBRARY
if fs.exists("json_lib.lua") then
    dofile("json_lib.lua")
else
    error("Library 'json_lib.lua' not found.")
end

-- check if we are running on a disk
if fs.exists("/disk/startup") then
    if not fs.exists("/startup") then
        fs.copy("/disk/startup", "/startup")
        shell.run("reboot")
    end
end

function undergoMitosis()
	turtle.select(getItemIndex("computercraft:peripheral"))
	if not turtle.place() then
		return nil
	end
	turtle.select(getItemIndex("computercraft:disk_expanded"))
	turtle.drop()	
	if not turtle.up() then
		return nil
	end
	turtle.select(getItemIndex("computercraft:turtle_expanded"))
	if not turtle.place() then
		return nil
	end
	turtle.select(1)
	turtle.drop(math.floor(turtle.getItemCount() / 2))
	os.sleep(1)
	peripheral.call("front", "turnOn")
	local cloneId = peripheral.call("front", "getID")
	if not turtle.down() then
		return nil
	end
	if not turtle.suck() then
		return nil
	end
	if not turtle.dig() then
		return nil
	end
	return cloneId
end

function GetGPSLocation()
    local X, Y, Z = gps.locate(5)
    if X == nil then
        return nil,nil,nil
    end
    return X, Y, Z
end

function mineTunnel(obj, ws)
	local file
	local blocks = {}
	for i=1,obj.length,1 do
		if obj.direction == 'forward' then
			turtle.dig()
			local success = turtle.forward()
			if not success then
				return res
			end
			ws.send(json.encode({move="f", nonce=obj.nonce}))
			blocks[i] = {}
			blocks[i][1] = select(2,turtle.inspectDown())
			blocks[i][2] = select(2,turtle.inspectUp())
			turtle.turnLeft()
			ws.send(json.encode({move="l", nonce=obj.nonce}))
			blocks[i][3] = select(2,turtle.inspect())
			turtle.turnRight()
			ws.send(json.encode({move="r", nonce=obj.nonce}))
			turtle.turnRight()
			ws.send(json.encode({move="r", nonce=obj.nonce}))
			blocks[i][4] = select(2,turtle.inspect())
			turtle.turnLeft()
			ws.send(json.encode({move="l", blocks=blocks[i], nonce=obj.nonce}))
		else
			if obj.direction == 'up' then 
				turtle.digUp()
				local success = turtle.up()
				if not success then
					return res
				end
				ws.send(json.encode({move="u", nonce=obj.nonce}))
			else
				turtle.digDown()
				local success = turtle.down()
				if not success then
					return res
				end
				ws.send(json.encode({move="d", nonce=obj.nonce}))
			end

			blocks[i] = {}
			blocks[i][1] = select(2,turtle.inspect())
			turtle.turnLeft()
			ws.send(json.encode({move="l", nonce=obj.nonce}))

			blocks[i][2] = select(2,turtle.inspect())
			turtle.turnLeft()
			ws.send(json.encode({move="l", nonce=obj.nonce}))

			blocks[i][3] = select(2,turtle.inspect())
			turtle.turnLeft()
			ws.send(json.encode({move="l", nonce=obj.nonce}))

			blocks[i][4] = select(2,turtle.inspect())
			ws.send(json.encode({blocks=blocks[i], nonce=obj.nonce}))
		end
	end
	return blocks
end

local X,Y,Z = 0,0,0
function websocketLoop()
	if fs.exists("WebSocketAddress.txt") then
		local WebSocketFile = fs.open("WebSocketAddress.txt", "r")
		WebsocketServer = WebSocketFile.readAll()
		WebSocketFile.close()
	end

	if WebsocketServer == "" then
		print("Invalid WebSocket address, retrying in 5 seconds...")
		os.sleep(5)
		return
	end

	local ws, err = http.websocket("ws://".. WebsocketServer)
	print("Connecting to WebSocket at: " .. WebsocketServer)
	if err then
		print("Connection failed: " .. err)
		ConnectionStatus = false
		return
	elseif ws then
		FailedToConnectAmount = 0
		ConnectionStatus = true
		term.clear()
		term.setCursorPos(1,1)
		print("Imperial Turtle Control OS")
		print("STATUS: ONLINE")
		while true do
			local message = ws.receive()
			if message == nil then
				break
			end
			local obj = json.decode(message)
			if obj.type == 'eval' then
				local func = loadstring(obj['function'])
				---@diagnostic disable-next-line: need-check-nil
				local result = func()
				ws.send(json.encode({data=result, nonce=obj.nonce}))
			elseif obj.type == 'mitosis' then
				local status, res = pcall(undergoMitosis)
				if not status then
					ws.send(json.encode({data="null", nonce=obj.nonce}))
				elseif res == nil then
					ws.send(json.encode({data="null", nonce=obj.nonce}))
				else
					ws.send(json.encode({data=res, nonce=obj.nonce}))
				end
			elseif obj.type == 'mine' then
				local status, res = pcall(mineTunnel, obj, ws)
				ws.send(json.encode({data="end", nonce=obj.nonce}))
            elseif obj.type == 'location' then
                X,Y,Z = GetGPSLocation()
                if X == nil then
                    ws.send(json.encode({data="null", nonce=obj.nonce}))
                else
                    ws.send(json.encode({data={X,Y,Z}, nonce=obj.nonce}))
                end
			end
		end
	end
	if ws then
		ws.close()
		print("Imperial Turtle Control OS")
		print("STATUS: OFFLINE")
		ConnectionStatus = false
	end
end

function main()
	turtle.refuel(64)
	term.clear()
	term.setCursorPos(1, 1)
	while true do
		local status, res = pcall(websocketLoop)
		if res == "Terminated" then
			print("Imperial Turtle Control OS")
			print("STATUS: OFFLINE")
			print("Imperial Turtle Control OS Terminated!")
			break
		end
		if ConnectionStatus == false then
			FailedToConnectAmount = FailedToConnectAmount + 1
			print("Imperial Turtle Control OS")
			print("STATUS: OFFLINE")
			print("Sleeping for 5 seconds before attempting reconnection")
			print("Failed to connect: " .. FailedToConnectAmount .. " times")
			if FailedToConnectAmount % 5 == 0 then
				if fs.exists("WebSocketAddress.txt") then
					fs.delete("WebSocketAddress.txt")
				end
				shell.run("pastebin get " .. WebSocketFilePastebinID .. " WebSocketAddress.txt")
			end
		end
		os.sleep(5)
	end
end

main()
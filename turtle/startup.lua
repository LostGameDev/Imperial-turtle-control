--[[
    Turtle Control OS
    Originally created by ottomated, modified by PrintedScript, Improved by LostGameDev
    https://github.com/PrintedScript/turtle-control
]]
-- Settings
local websocketServer = "ws://localhost:5757"

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
	
	local ws, err = http.websocket(websocketServer)
 
	if err then
		print(err)
	elseif ws then
		while true do
			term.clear()
			term.setCursorPos(1,1)
			print("Turtle Control OS, originally created by Ottomated. Modified by PrintedScript")
            print("View the project on github! https://github.com/PrintedScript/turtle-control")
			local message = ws.receive()
			if message == nil then
				break
			end
			local obj = json.decode(message)
			if obj.type == 'eval' then
				local func = loadstring(obj['function'])
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
	end
end

while true do
	local status, res = pcall(websocketLoop)
	term.clear()
	term.setCursorPos(1,1)
	if res == 'Terminated' then
		print("Turtle Control OS terminated")
		break
	end
	print("Sleeping for 5 seconds before attempting reconnection - Turtle Control OS - https://github.com/PrintedScript/turtle-control")
	os.sleep(5)
end
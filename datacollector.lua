--Collects data from SMB gameplay for machine learning experiments

require "os"
local bit = require("bit")

--romname = rom.getfilename()	--FCEUX 2.2.3 only
--print(romname)

print(_VERSION)

local user = os.getenv("USERNAME")

--GENERAL CONFIGURATION
SCREEN_WIDTH = 256
SCREEN_HEIGHT = 240
COLLECT_IMAGES = true
INDEXED_COLORS = true
COLLECT_RAM = true
RAM_START = 0
RAM_END = 2047
SKIP = 0
COLLECT_BUTTONS_P1 = true
COLLECT_BUTTONS_P2 = false
COLLECT_OUTCOMES = true
DATA_FOLDER = "data\\"
COMPRESS = true
--Requires 7zip (and it must be on Windows path)
COMPRESSION_CMD = "7z a -r -mx9 -mmt4 " .. DATA_FOLDER .. "data-" .. user .. ".7z %s"
DELETION_CMD = "del /S " .. DATA_FOLDER .. "*.png & for /D %f in (" .. DATA_FOLDER .. user .. "_*) do rd %f"
STORE_IN_PNG = true

--GAME SPECIFIC CONFIGURATION
LIVES_ADDRESS = 0x075A
WORLD_ADDRESS = 0x075F 
LEVEL_ADDRESS = 0x075C
lives = -1
level = 0

--Return true whenever it is appropriate to collect data
function mustCollect()	
	local PAUSED_ADDRESS = 0x0776 	--do not collect data while this address is not 0
	local OPERMODE = 0x0770
	local PLAYING_ADDRESS = 0x0772 	--do not collect data while in this state, starts new episode after that
	local PLAYING_VALUE = 3
	return memory.readbyte(PLAYING_ADDRESS) == PLAYING_VALUE and memory.readbyte(PAUSED_ADDRESS) == 0 and memory.readbyte(OPERMODE) == 1
end

--Build the screenshot filename
function getFileName()
	local now = os.date("%Y-%m-%d_%H-%M-%S")
	local name = ""
	if user ~= nil and user ~= "" then
		name = user .. "_"
	end
	name = name .. SESSID .. "_e" .. episode .. "_" .. (memory.readbyte(WORLD_ADDRESS) + 1) .. "-" .. (memory.readbyte(LEVEL_ADDRESS) + 1) .. "_f" .. frame .. "_a" .. getAction(1) .. "_" .. now .. ".png"
	return name
end

--Build the screenshot folder name
function getFolderName()
	local name = ""
	if user ~= nil and user ~= "" then
		name = user .. "_"
	end
	name = name .. SESSID .. "_e" .. episode .. "_" .. (memory.readbyte(WORLD_ADDRESS) + 1) .. "-" .. (memory.readbyte(LEVEL_ADDRESS) + 1)
	return name
end

--Return true if the player has failed / died, false otherwise
function isFailure()
	local OPERMODE = 0x0770
	local l = memory.readbyte(LIVES_ADDRESS)
	local f = false
	if ((l < lives and lives ~= 255)  or (lives == 0 and l == 255)) and memory.readbyte(OPERMODE) > 0 then
		f = true
	end
	lives = l
	return f
end

--Return true if the player has succeded / finished a level, false otherwise
function isSuccess()
	local lv = memory.readbyte(LEVEL_ADDRESS)
	local l = memory.readbyte(LIVES_ADDRESS)
	local s = false
	if lv ~= level and l >= 0 and l < 255 then
		s = true
	end
	level = lv
	return s
end

--INITIALIZATION
frame = 0
episode = 0
frames = {}
failure = false
success = false

function randomString(length)
	local chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
	local randomStr = ''

	math.randomseed(os.time())

	charTable = {}
	for c in chars:gmatch"." do
		table.insert(charTable, c)
	end

	for i = 1, length do
		randomStr = randomStr .. charTable[math.random(1, #charTable)]
	end
	
	return randomStr
end

SESSID = randomString(8)

function bool2int(x)
	return x and 1 or 0
end

function bytes(x)
    local b4=x%256  x=(x-x%256)/256
    local b3=x%256  x=(x-x%256)/256
    local b2=x%256  x=(x-x%256)/256
    local b1=x%256  x=(x-x%256)/256
    return string.char(b1,b2,b3,b4)
end

function pngWriteTextChunk(file, key, value)
	local length = key:len() + 1 + value:len()
	file:write(bytes(length))
	file:write("tEXt" .. key .. "\0" .. value)
	file:write("\0\0\0\0")	--Fake CRC
end

function writePNGData()
	emu.message("Writing RAM and controls data into screenshots' metadata...")
	local folder
	for i,v in ipairs(frames) do
		local file = io.open(DATA_FOLDER .. v.folder .. "\\" .. v.filename, "a")
		folder = v.folder
		if file ~= nil then
			if COLLECT_RAM then
				local ramstr = ""
				for addr = RAM_START, RAM_END do
					ramstr = ramstr .. string.char(v.ram[addr])
				end
				pngWriteTextChunk(file, "RAM", ramstr)			
			end
			if COLLECT_BUTTONS_P1 then
				pngWriteTextChunk(file, "BP1", string.char(v.buttons1))
			end
			if COLLECT_BUTTONS_P2 then
				pngWriteTextChunk(file, "BP2", string.char(v.buttons2))
			end
			if COLLECT_OUTCOMES then
				pngWriteTextChunk(file, "OUTCOME", string.char(2 * bool2int(success) + bool2int(failure)))
			end
			file:close()
		end
		if COLLECT_OUTCOMES then
			local newname = v.filename
			if failure then
				newname = string.gsub(newname, ".png", ".fail.png")
			elseif success then
				newname = string.gsub(newname, ".png", ".win.png")				
			end
			os.rename(DATA_FOLDER .. v.folder .. "\\" .. v.filename, DATA_FOLDER .. v.folder .. "\\" .. newname)		
		end
	end
	if folder ~= nil then
		if failure then
			os.rename(DATA_FOLDER .. folder, DATA_FOLDER .. folder .. "_fail")
		elseif success then
			os.rename(DATA_FOLDER .. folder, DATA_FOLDER .. folder .. "_win")
		end
	end
end

function compress()
	emu.message("Compressing...")
	os.execute(string.format(COMPRESSION_CMD, DATA_FOLDER .. "*.png"))
	if DELETION_CMD ~= "" then
		emu.message("Removing files...")
		os.execute(DELETION_CMD)
	end
end

function getAction(p)
	local buttons = joypad.get(p)
	local bt = 0
	for k,v in pairs(buttons) do
		bt = bit.lshift(bt, 1) + bool2int(v)
	end
	return bt
end

--EVENTS
function onAfterStep()
	failure = isFailure()
	success = isSuccess()
	if mustCollect() then
		frame = frame + 1
		if frame % (SKIP + 1) == 0 then
			local screenshot_filename = getFileName()
			local folder_ = getFolderName()
			gui.savescreenshotas(DATA_FOLDER .. folder_  .. "\\" .. screenshot_filename)
			frames[frame] = {filename = screenshot_filename, folder = folder_, ram = {}}
			if COLLECT_RAM then
				for addr = RAM_START, RAM_END do
					frames[frame].ram[addr] = memory.readbyte(addr)
				end
			end
			if COLLECT_BUTTONS_P1 then
				frames[frame].buttons1 = getAction(1)
			end
			if COLLECT_BUTTONS_P2 then
				frames[frame].buttons2 = getAction(2)
			end
		end
	end
		
	if failure or success then	--EPISODE ENDED
		onExit()
		--START NEW LOG
		episode = episode + 1
		frames = nil
		collectgarbage()
		frames = {}
		frame = 0
		failure = false
		success = false
	end

end

emu.registerafter(onAfterStep)

function onExit()
	print("EPISODE " .. episode .. " END")
	if STORE_IN_PNG then
		writePNGData()
	end
	if COMPRESS and COMPRESSION_CMD ~= "" then
		compress()
	end
end

emu.registerexit(onExit)

--MAIN LOOP
print("Collecting data...")
while true do
	emu.frameadvance()
end
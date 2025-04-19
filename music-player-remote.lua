-- Remote control for music player broadcast
local modem = peripheral.find("modem")
local speaker = peripheral.find("speaker")

if not modem then
    error("No modem found")
end

if not speaker then
    error("No speaker found")
end

if not modem.isWireless() then
    error("Wireless modem required")
end

-- Load configuration file
local audioConfig = {}
local channels = {} -- 存储所有监听的频道

-- 加载频道配置
local function loadChannels()
    if fs.exists("channels.lua") then
        local file = fs.open("channels.lua", "r")
        if file then
            local data = file.readAll()
            file.close()
            local success, result = load(data)
            if success then
                local config = success()
                if type(config) == "table" then
                    channels = config
                    return true
                end
            end
        end
    end
    return false
end

-- 在程序启动时加载频道配置
print("[Init] Loading channel configuration...")
if loadChannels() then
    print("[Init] Successfully loaded " .. #channels .. " channels")
else
    print("[Error] No channels configured. Please run install-radio first")
    error("No channels configured")
end

-- 广播消息到所有频道
local function broadcastToChannels(message)
    for _, channel in ipairs(channels) do
        modem.transmit(channel, channel, message)
    end
end

-- Enable wireless communication
print("[Init] Found wireless modem: " .. peripheral.getName(modem))
modem.open(65492)  -- 添加默认频道监听
for _, channel in ipairs(channels) do
    modem.open(channel)
end
print("[Init] Opened channels: 65492, " .. table.concat(channels, ", ") .. " for listening")

-- Save configuration to file
local function saveConfig()
    local file = fs.open("disk/audiolist.lua", "w")  -- 修改保存路径
    if file then
        file.write("return ")
        file.write(textutils.serialize(audioConfig))
        file.close()
        return true
    end
    return false
end

-- Load configuration from file
local function loadConfig()
    if fs.exists("disk/audiolist.lua") then  -- 修改读取路径
        local file = fs.open("disk/audiolist.lua", "r")
        if file then
            local data = file.readAll()
            file.close()
            local success, result = load(data)
            if success then
                local config = success()
                if type(config) == "table" then
                    audioConfig = config
                    return true
                end
            end
        end
    end
    return false
end

-- Load initial configuration
print("[Init] Loading audio configuration...")
if loadConfig() then
    print("[Init] Successfully loaded audio configuration with " .. #audioConfig .. " entries")
else
    print("[Warning] Failed to load audio configuration, using empty list")
end

-- Function to check modem status
local function checkModemStatus()
    while true do
        local status = {}
        for _, channel in ipairs(channels) do
            status[#status + 1] = string.format("%d: %s", channel, tostring(modem.isOpen(channel)))
        end
        print("[Status] Modem channels status - " .. table.concat(status, ", "))
        os.sleep(5)
    end
end

-- Function to handle modem messages
local function handleModemMessages()
    while true do
        local event, side, channel, replyChannel, message = os.pullEvent("modem_message")
        
        -- 设置不同日志级别的颜色
        local function coloredPrint(level, message)
            local color = colors.white
            if level == "Debug" then
                color = colors.gray
            elseif level == "Info" then
                color = colors.blue
            elseif level == "Warning" then
                color = colors.orange
            elseif level == "Error" then
                color = colors.red
            elseif level == "Success" then
                color = colors.green
            elseif level == "Receive" then
                color = colors.lightBlue
            end
            
            term.setTextColor(color)
            print("["..level.."] "..message)
            term.setTextColor(colors.white)
        end

        if table.concat(channels, ","):find(tostring(channel)) then
            coloredPrint("Info", "Message received on channel: " .. channel)
            if type(message) == "table" then
                coloredPrint("Info", "Message type: " .. tostring(message.type))
                if message.data then
                    coloredPrint("Info", "Message data: " .. (
                        type(message.data) == "table" 
                        and "table[" .. #message.data .. "]" 
                        or tostring(message.data)
                    ))
                end
                
                if message.type == "config_update" and message.action == "update" and type(message.data) == "table" then
                    coloredPrint("Receive", "Received audio configuration update")
                    local oldConfigCount = #audioConfig
                    audioConfig = message.data
                    if saveConfig() then
                        coloredPrint("Success", string.format("Configuration updated (Old: %d, New: %d items)", oldConfigCount, #audioConfig))
                        broadcastToChannels({type = "ack", action = "config_update", status = "updated"})
                    else
                        coloredPrint("Error", "Failed to save configuration")
                        broadcastToChannels({type = "error", action = "config_update", message = "Failed to save configuration"})
                    end
                elseif message.type == "broadcast" and message.action == "play" then
                    coloredPrint("Receive", "Play Audio Index: " .. message.data)
                    if message.data > 0 and message.data <= #audioConfig then
                        local audio = audioConfig[message.data]
                        coloredPrint("Info", "Playing audio: " .. audio.name)
                        local command = string.format("austream %s volume=%.1f", audio.url, audio.volume)
                        shell.run(command)
                        coloredPrint("Success", "Started playing audio")
                        broadcastToChannels({type = "ack", action = "play", status = "playing"})
                    else
                        coloredPrint("Error", "Invalid audio index")
                        broadcastToChannels({type = "error", action = "play", message = "Invalid audio index"})
                    end
                elseif message.type == "stop" then
                    coloredPrint("Receive", "Stop playing command")
                    os.queueEvent("speaker_audio_empty")
                    coloredPrint("Success", "Stopped playing audio")
                    broadcastToChannels({type = "ack", action = "stop", status = "stopped"})
                elseif message.type == "volume" and type(message.data) == "number" then
                    coloredPrint("Receive", "Volume adjustment to: " .. message.data)
                    if message.data >= 0.1 and message.data <= 3.0 then
                        for _, audio in ipairs(audioConfig) do
                            audio.volume = message.data
                        end
                        saveConfig()
                        coloredPrint("Success", "Volume adjusted to: " .. message.data)
                        broadcastToChannels({type = "ack", action = "volume", status = "updated"})
                    else
                        coloredPrint("Error", "Invalid volume value: " .. message.data)
                        broadcastToChannels({type = "error", action = "volume", message = "Volume must be between 0.1 and 3.0"})
                    end
                elseif message.type == "config_update" and message.action == "update" and type(message.data) == "table" then
                    coloredPrint("Receive", "Configuration update")
                    local oldConfigCount = #audioConfig
                    audioConfig = message.data
                    if saveConfig() then
                        coloredPrint("Sync", string.format("Configuration updated (Old: %d, New: %d items)", oldConfigCount, #audioConfig))
                        broadcastToChannels({type = "ack", action = "config_update", status = "updated"})
                    else
                        coloredPrint("Error", "Failed to save configuration")
                        broadcastToChannels({type = "error", action = "config_update", message = "Failed to save configuration"})
                    end
                elseif message.type == "exit" then
                    coloredPrint("Receive", "Exit command")
                    os.queueEvent("speaker_audio_empty") -- Stop current audio playback
                    shell.run("killall austream") -- Force stop any running audio
                    os.sleep(0.5) -- Wait for events to be processed
                    broadcastToChannels({type = "ack", action = "exit", status = "exiting"})
                    coloredPrint("Exit", "Stopping audio playback...")
                else
                    coloredPrint("Warning", "Unknown message type or invalid data format")
                end
            else
                coloredPrint("Warning", "Received message is not a table")
            end
        else
            coloredPrint("Warning", "Message received on unregistered channel: " .. tostring(channel))
        end
    end
end

-- Main program
print("[Start] Music player remote control started")
print("[Start] Listening for wireless messages...")

-- Start status checking in parallel
parallel.waitForAll(handleModemMessages, checkModemStatus)

-- Close modem before exit
for _, channel in ipairs(channels) do
    modem.close(channel)
end
print("[Exit] Closed channels: " .. table.concat(channels, ", "))

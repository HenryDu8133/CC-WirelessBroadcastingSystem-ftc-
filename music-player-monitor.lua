-- Monitor program for music-player-remote.lua

local function log(message)
    local file = fs.open("monitor.log", "a")
    if file then
        file.write("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] " .. message .. "\n")
        file.close()
    end
    print(message)
end

local function isProcessRunning()
    local running = false
    for _, process in ipairs(multishell.list()) do
        if process.getTitle():find("music%-player%-remote") then
            running = true
            break
        end
    end
    return running
end

local function startRemotePlayer()
    log("Starting music-player-remote.lua...")
    multishell.launch({}, "music-player-remote.lua")
end

-- Main monitoring loop
log("Monitor started")

while true do
    if not isProcessRunning() then
        log("music-player-remote.lua is not running, restarting...")
        startRemotePlayer()
    end
    os.sleep(5) -- Check every 5 seconds
end
-- Radio System Installer
local files = {
    {
        name = "music-player-remote.lua",
        url = "http://115.231.176.136:5244/d/Storage%231/CC-Lua/Radio-broadcasting-system/Reciever/music-player-remote.lua?sign=KM4WHSDvDzLUH43IChCNWoPwjhz9PIK92YyWz_we1gc=:0"
    },
    {
        name = "austream.lua",
        url = "http://115.231.176.136:5244/d/Storage%231/CC-Lua/Radio-broadcasting-system/Reciever/austream.lua?sign=OHGmawuRSXmeXi50f2--50Hwuqe58dGgejEs2jbTo8Q=:0"
    },
    {
        name = "aukit.lua",
        url = "http://115.231.176.136:5244/d/Storage%231/CC-Lua/Radio-broadcasting-system/Reciever/aukit.lua?sign=jYgd31d7hgoDYMWauR-hBDmkd3l4DW0RWqF50daky5s=:0"
    }
}

-- 添加颜色打印函数
local function colorPrint(level, message)
    local color = colors.white
    if level == "Info" then
        color = colors.blue
    elseif level == "Success" then
        color = colors.green
    elseif level == "Warning" then
        color = colors.orange
    elseif level == "Error" then
        color = colors.red
    elseif level == "Input" then
        color = colors.yellow
    elseif level == "Progress" then
        color = colors.lightBlue
    end
    
    term.setTextColor(color)
    print("["..level.."] "..message)
    term.setTextColor(colors.white)
end

-- Function to download a file
local function downloadFile(url, filename)
    colorPrint("Progress", "Downloading " .. filename .. "...")
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        
        local file = fs.open(filename, "w")
        file.write(content)
        file.close()
        colorPrint("Success", "Successfully downloaded " .. filename)
        return content
    else
        colorPrint("Error", "Failed to download " .. filename)
        error("Download failed")
    end
    return nil
end

-- Function to get channels from user
local function getChannels()
    local channels = {}
    colorPrint("Info", "\nPlease enter the channel numbers you want to listen to (Enter empty line to finish):")
    while true do
        term.setTextColor(colors.yellow)
        write("Channel number (or press Enter to finish): ")
        term.setTextColor(colors.white)
        local input = read()
        if input == "" then
            break
        end
        local number = tonumber(input)
        if number then
            table.insert(channels, number)
            colorPrint("Success", "Added channel: " .. number)
        else
            colorPrint("Warning", "Please enter a valid number")
        end
    end
    return channels
end

-- Function to modify remote file content
local function modifyRemoteFile(content, channels)
    local modified = content
    -- Find and replace all instances of channel 65492
    local channelOpens = {}
    for _, channel in ipairs(channels) do
        table.insert(channelOpens, string.format("modem.open(%d)", channel))
    end
    
    -- Replace all instances of modem.open(65492)
    modified = string.gsub(modified, "modem%.open%(65492%)", table.concat(channelOpens, "\n"))
    
    -- Update all channel checks in the message handler
    local channelChecks = {}
    for _, channel in ipairs(channels) do
        table.insert(channelChecks, string.format("channel == %d", channel))
    end
    
    -- Replace all instances of channel == 65492
    modified = string.gsub(modified, "channel%s*==%s*65492", table.concat(channelChecks, " or "))
    
    -- Update modem close
    local channelCloses = {}
    for _, channel in ipairs(channels) do
        table.insert(channelCloses, string.format("modem.close(%d)", channel))
    end
    
    -- Replace all instances of modem.close(65492)
    modified = string.gsub(modified, "modem%.close%(65492%)", table.concat(channelCloses, "\n"))
    
    -- Replace channel number in status check
    local statusChecks = {}
    for _, channel in ipairs(channels) do
        table.insert(statusChecks, string.format("modem.isOpen(%d)", channel))
    end
    modified = string.gsub(modified, "modem%.isOpen%(65492%)", table.concat(statusChecks, " and "))
    
    -- Update print messages
    modified = string.gsub(modified, "Opened channel 65492", "Opened channels: "..table.concat(channels, ", "))
    modified = string.gsub(modified, "Closed channel 65492", "Closed channels: "..table.concat(channels, ", "))
    
    return modified
end

-- Main installation process
term.setTextColor(colors.lime)
print("=== Radio System Installer ===")
term.setTextColor(colors.white)

-- Get channels from user first
colorPrint("Info", "First, let's configure your channels")

local function saveChannels(channels)
    local file = fs.open("channels.lua", "w")
    if file then
        file.write("return ")
        file.write(textutils.serialize(channels))
        file.close()
        return true
    end
    return false
end

local channels = getChannels()
if #channels == 0 then
    colorPrint("Error", "No channels specified. Installation cancelled.")
    error("Installation cancelled")
end

colorPrint("Progress", "\nSaving channel configuration...")
if saveChannels(channels) then
    colorPrint("Success", "Channel configuration saved successfully")
else
    colorPrint("Error", "Failed to save channel configuration")
    error("Configuration save failed")
end

colorPrint("Info", "\nStarting installation with channels: " .. table.concat(channels, ", "))

-- Download and process files
for _, file in ipairs(files) do
    local content = downloadFile(file.url, file.name)
    if file.name == "music-player-remote.lua" and content then
        colorPrint("Progress", "Modifying channel configuration...")
        local modified = modifyRemoteFile(content, channels)
        local file = fs.open(file.name, "w")
        file.write(modified)
        file.close()
        colorPrint("Success", "Channel configuration updated")
    end
end

-- 添加自动重命名功能
colorPrint("Progress", "Setting up auto-start...")
if fs.exists("startup") then
    fs.delete("startup")
end
fs.move("music-player-remote.lua", "startup")
colorPrint("Success", "Auto-start configured")

colorPrint("Success", "\nInstallation completed successfully!")
colorPrint("Info", "The radio receiver will automatically start on system boot")
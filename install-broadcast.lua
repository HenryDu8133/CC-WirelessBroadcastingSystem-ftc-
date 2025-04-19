-- Radio System Installer
local files = {
    {
        name = "music-player-broadcast.lua",
        url = "http://115.231.176.136:5244/d/Storage%231/CC-Lua/Radio-broadcasting-system/Sender/music-player-broadcast.lua?sign=8gTAFRJp5VLdti-ey6g_9dBbrWjCT29ImbsSpZgXrrw=:0"
    },
    {
        name = "austream.lua",
        url = "http://115.231.176.136:5244/d/Storage%231/CC-Lua/Radio-broadcasting-system/Sender/austream.lua?sign=ip3rLiLnH1DHj0I-uaf7J7AYEaWHodhqzC-q5_Et9d0=:0"
    },
    {
        name = "aukit.lua",
        url = "http://115.231.176.136:5244/d/Storage%231/CC-Lua/Radio-broadcasting-system/Sender/aukit.lua?sign=oZWzWLUDef7ll7YBe1TjpwGXuE-Gb5Mfv0EJcIxmlgw=:0"
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
        return true
    else
        colorPrint("Error", "Failed to download " .. filename)
        error("Download failed")
    end
    return false
end

-- Main installation process
term.setTextColor(colors.lime)
print("=== Radio Broadcast System Installer ===")
term.setTextColor(colors.white)

colorPrint("Info", "Starting installation...")

-- Download files
for _, file in ipairs(files) do
    downloadFile(file.url, file.name)
end

-- 添加自动重命名功能
colorPrint("Progress", "Setting up auto-start...")
if fs.exists("startup") then
    fs.delete("startup")
end
fs.move("music-player-broadcast.lua", "startup")
colorPrint("Success", "Auto-start configured")

colorPrint("Success", "\nInstallation completed successfully!")
colorPrint("Info", "The broadcast system will automatically start on system boot")
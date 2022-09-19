local JSON = require("jsonLib")

local Update = {}

function Update:__init(updateVersion, scriptName, scriptVersion)
	print("Updating")
    self.currentVersion = version
    self.scriptName = scriptName
    self.scriptVersion = scriptVersion
    self.scriptUpdate = ""

    self:downloadVersion()
end

---@return nil
function Update:downloadVersion()
    _G.net.getAsync(self.scriptVersion, function(response)
        if not response then
            return chat.showChat("<font color=\"#FF0000\">[" .. self.scriptName .. "]</font> <font color=\"#FFFFFF\">An error has occurred: no response</font>")
        end

        if response.status ~= 200 then
            return chat.showChat("<font color=\"#FF0000\">[" .. self.scriptName .. "]</font> <font color=\"#FFFFFF\">An error has occurred: " .. response.status .. "</font>")
        end

        local json = JSON.decode(response.text)

        if not json["success"] then
            return chat.showChat("<font color=\"#FF0000\">[" .. self.scriptName .. "]</font> <font color=\"#FFFFFF\">" .. json["message"] .. "</font>")
        end

            self.scriptUpdate = json["update"]
            self:downloadUpdate()
    end)
end

---@return nil
function Update:downloadUpdate()
    _G.net.autoUpdate(self.scriptUpdate, self.scriptName, function(success)
        if not success then
            return chat.showChat("<font color=\"#FF0000\">[" .. self.scriptName .. "]</font> <font color=\"#FFFFFF\">The update failed! (v" .. updateVersion .. ")</font>")
        end
    
        chat.showChat("<font color=\"#1E90FF\">[" .. self.scriptName .. "]</font> <font color=\"#FFFFFF\">Update completed successfully, please press F5 to refresh! (v" .. updateVersion .. ")</font>")
    end)
end

return Update
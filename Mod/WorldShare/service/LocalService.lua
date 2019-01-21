﻿--[[
Title: LocalService
Author(s):  big
Date:  2016.12.11
Desc: 
use the lib:
------------------------------------------------------------
local LocalService = NPL.load("(gl)Mod/WorldShare/service/LocalService.lua")
------------------------------------------------------------
]]
NPL.load("./FileDownloader/FileDownloader.lua")
local Files = commonlib.gettable("commonlib.Files")

local SystemEncoding = commonlib.gettable("System.Encoding")
local CommonlibEncoding = commonlib.gettable("commonlib.Encoding")
local FileDownloader = commonlib.gettable("Mod.WorldShare.service.FileDownloader.FileDownloader")

local GitlabService = NPL.load("./GitlabService")
local GithubService = NPL.load("./GithubService")
local GitEncoding = NPL.load("(gl)Mod/WorldShare/helper/GitEncoding.lua")
local UserConsole = NPL.load("(gl)Mod/WorldShare/cellar/Login/UserConsole.lua")
local SyncMain = NPL.load("(gl)Mod/WorldShare/cellar/Sync/Main.lua")
local Store = NPL.load("(gl)Mod/WorldShare/store/Store.lua")
local Utils = NPL.load("(gl)Mod/WorldShare/helper/Utils.lua")

local LocalService = NPL.export()

LocalService.filter = "*"
LocalService.nMaxFileLevels = 0
LocalService.nMaxFilesNum = 500
LocalService.output = {}

function LocalService:LoadFiles(worldDir)
    self.output = {}

    if (string.sub(worldDir, -1, -1) == "/") then
        self.worldDir = string.sub(worldDir, 1, -2)
    end

    local result = Files.Find({}, self.worldDir, self.nMaxFileLevels, self.nMaxFilesNum, self.filter)

    self:FilesFind(result, self.worldDir)

    for _, item in ipairs(self.output) do
        item.filename = CommonlibEncoding.DefaultToUtf8(item.filename)
    end

    Store:Set('world/localFiles', self.output)

    return self.output
end

function LocalService:FilesFind(result, path, subPath)
    local curResult = commonlib.copy(result)
    local curPath = commonlib.copy(path)
    local curSubPath = commonlib.copy(subPath)

    if (type(curResult) == "table") then
        local convertLineEnding = {[".xml"] = true, [".bmax"] = true, [".txt"] = true, [".md"] = true, [".lua"] = true}
        local zipFile = {[".xml"] = true, [".bmax"] = true}

        for key, item in ipairs(curResult) do
            if (item.filesize ~= 0) then
                item.file_path = curPath .. "/" .. item.filename

                if (curSubPath) then
                    item.filename = curSubPath .. "/" .. item.filename
                end

                local sExt = item.filename:match("%.[^&.]+$")

                if (sExt == ".bak") then
                    item = false
                else
                    local bConvert = false

                    if (convertLineEnding[sExt] and zipFile[sExt]) then
                        bConvert = not self:IsZip(item.file_path)
                    elseif (convertLineEnding[sExt]) then
                        bConvert = true
                    end

                    if (bConvert) then
                        item.file_content_t = self:GetFileContent(item.file_path):gsub("\r\n", "\n")
                        item.filesize = #item.file_content_t
                        item.sha1 = SystemEncoding.sha1("blob " .. item.filesize .. "\0" .. item.file_content_t, "hex")
                    else
                        item.file_content_t = self:GetFileContent(item.file_path)
                        item.sha1 = SystemEncoding.sha1("blob " .. item.filesize .. "\0" .. item.file_content_t, "hex")
                    end

                    item.needChange = true

                    self.output[#self.output + 1] = item
                end
            else
                local newPath = curPath .. "/" .. item.filename
                local newResult = Files.Find({}, newPath, self.nMaxFileLevels, self.nMaxFilesNum, self.filter)
                local newSubPath = nil

                if (curSubPath) then
                    newSubPath = curSubPath .. "/" .. item.filename
                else
                    newSubPath = item.filename
                end

                self:FilesFind(newResult, newPath, newSubPath)
            end
        end
    end
end

function LocalService:GetFileContent(filePath)
    local file = ParaIO.open(filePath, "r")
    if (file:IsValid()) then
        local fileContent = file:GetText(0, -1)
        file:close()
        return fileContent
    end
end

function LocalService:Write(foldername, path, content)
    local writePath = format("%s/%s/%s", SyncMain.GetWorldFolderFullPath(), foldername, path)
    local write = ParaIO.open(writePath, "w")

    write:write(content, #content)
    write:close()
end

function LocalService:Delete(foldername, filename)
    local deletePath = format("%s/%s/%s", SyncMain.GetWorldFolderFullPath(), foldername, filename)

    ParaIO.DeleteFile(deletePath)
end

function LocalService:IsZip(path)
    local file = ParaIO.open(path, "r")
    local fileType = nil

    if (file:IsValid()) then
        local o = {}

        file:ReadBytes(2, o)

        if (o[1] and o[2]) then
            fileType = o[1] .. o[2]
        end

        file:close()
    end

    if (fileType and fileType == "8075") then
        return true
    else
        return false
    end
end

function LocalService:MoveZipToFolder(path)
    if (not ParaAsset.OpenArchive(path, true)) then
        return false
    end

    local foldername = Store:Get("world/foldername")

    if (not foldername) then
        return false
    end

    local parentDir = path:gsub("[^/\\]+$", "")

    local filesOut = {}
    commonlib.Files.Find(filesOut, "", 0, 10000, ":.", path) -- ":.", any regular expression after : is supported. `.` match to all strings.

    local bashPath = format("%s/%s/", SyncMain.GetWorldFolderFullPath(), foldername.default)

    local folderCreate = ""
    local rootFolder = filesOut[1] and filesOut[1].filename

    for _, item in ipairs(filesOut) do
        if (item.filesize > 0) then
            local file = ParaIO.open(format("%s%s", parentDir, item.filename), "r")

            if (file:IsValid()) then
                local binData = file:GetText(0, -1)
                local pathArray = {}
                local path = commonlib.copy(item.filename)

                path = path:sub(#rootFolder, #path)

                if (path == "/revision.xml") then
                    Store:Set('remoteRevision', binData)
                end

                for segmentation in string.gmatch(path, "[^/]+") do
                    if (segmentation ~= rootFolder) then
                        pathArray[#pathArray + 1] = segmentation
                    end
                end

                folderCreate = commonlib.copy(bashPath)

                for i = 1, #pathArray - 1, 1 do
                    folderCreate = folderCreate .. pathArray[i] .. "/"
                    ParaIO.CreateDirectory(folderCreate)
                end

                local writeFile = ParaIO.open(format("%s%s", bashPath, path), "w")

                writeFile:write(binData, #binData)
                writeFile:close()

                file:close()
            end
        else
            -- this is a folder
        end
    end

    ParaAsset.CloseArchive(path)
end

function LocalService:FileDownloader(foldername, path, callback)
    local foldername = GitEncoding.Base32(SyncMain.foldername.utf8)

    local url = ""
    local downloadDir = ""

    if (UserConsole.dataSourceType == "github") then
    elseif (UserConsole.dataSourceType == "gitlab") then
        url =
            UserConsole.rawBaseUrl ..
            "/" .. UserConsole.dataSourceUsername .. "/" .. foldername .. "/raw/" .. SyncMain.commitId .. "/" .. path
        downloadDir = SyncMain.worldDir.default .. path
    end

    local Files =
        FileDownloader:new():Init(
        _path,
        url,
        downloadDir,
        function(bSuccess, downloadPath)
            local content = LocalService:getFileContent(downloadPath)

            if (bSuccess) then
                local returnData = {filename = _path, content = content}
                return callback(bSuccess, returnData)
            else
                return callback(bSuccess, nil)
            end
        end,
        "access plus 5 mins",
        true
    )
end

function LocalService:GetWorldSize(WorldDir)
    local files =
        commonlib.Files.Find(
        {},
        WorldDir,
        5,
        5000,
        function(item)
            return true
        end
    )

    local filesTotal = 0
    for key, value in ipairs(files) do
        filesTotal = filesTotal + tonumber(value.filesize)
    end

    return filesTotal
end

function LocalService:GetZipWorldSize(zipWorldDir)
    return ParaIO.GetFileSize(zipWorldDir)
end

function LocalService:GetZipRevision(zipWorldDir)
    local zipParentDir = zipWorldDir:gsub("[^/\\]+$", "")

    local needToClose

    if(System.World.worldzipfile ~= zipWorldDir) then
        ParaAsset.OpenArchive(zipWorldDir, true)
        needToClose = true;
    end

    local output = {}

    Files.Find(output, "", 0, 500, ":revision.xml", zipWorldDir)

    local binData = 0
    if (#output ~= 0) then
        local file = ParaIO.open(zipParentDir .. output[1].filename, "r")

        if (file:IsValid()) then
            binData = file:GetText(0, -1)
            --LOG.std(nil,"debug","binData",binData);
            file:close()
        end
    end

    if(needToClose) then
        ParaAsset.CloseArchive(zipWorldDir)
    end

    return binData
end

function LocalService:SetTag(worldDir, newTag)
    if (type(worldDir) == "string" and type(newTag) == "table") then
        local tagTable = {
            {
                attr = newTag,
                name = "pe:world"
            },
            name = "pe:mcml"
        }

        local xmlString = commonlib.Lua2XmlString(tagTable, true, true)

        local filePath = worldDir .. "/tag.xml"

        local file = ParaIO.open(filePath, "w")

        file:write(xmlString, #xmlString)
        file:close()
    end
end

function LocalService:GetTag(foldername)
    if (not foldername) then
        return {}
    end

    local filePath = format("%s/%s/tag.xml", SyncMain:GetWorldFolderFullPath() , foldername)
    local tag = ParaXML.LuaXML_ParseFile(filePath)

    if (type(tag) == "table" and type(tag[1]) == "table" and type(tag[1][1]) == "table") then
        return tag[1][1]["attr"]
    else
        return {}
    end
end

function LocalService:SaveWorldInfo(ctx, node)
    if (type(ctx) ~= 'table' or
        type(node) ~= 'table' or
        type(node.attr) ~= 'table') then
        return false
    end

    node.attr.clientversion = self:GetClientVersion() or ctx.clientversion

    local enterWorld = Store:Get('world/enterWorld')
    node.attr.kpProjectId = enterWorld and enterWorld.kpProjectId or ctx.kpProjectId
end

function LocalService:LoadWorldInfo(ctx, node)
    if (type(ctx) ~= 'table' or
        type(node) ~= 'table' or
        type(node.attr) ~= 'table') then
        return false
    end
    ctx.clientversion = node.attr.clientversion

    local enterWorld = Store:Get('world/enterWorld')

    if type(enterWorld) == 'table' and enterWorld.kpProjectId then
        ctx.kpProjectId = enterWorld.kpProjectId
    else 
        ctx.kpProjectId = node.attr.kpProjectId
    end
end

function LocalService:GetClientVersion(node)
    return System and System.options and System.options.ClientVersion and System.options.ClientVersion
end

function LocalService:ClearUserWorlds()
    local userworldsPath = format("%s/%s", SyncMain:GetWorldFolderFullPath(), "userworlds")

    local fileLists = Files.Find(nil, userworldsPath, self.nMaxFileLevels, self.nMaxFilesNum, self.filter)

    for key, item in ipairs(fileLists) do
        if item.fileattr and item.fileattr == 16 then
            if (GameLogic.RemoveWorldFileWatcher) then
                GameLogic.RemoveWorldFileWatcher()
            end

            Files.DeleteFolder(format("%s/%s", userworldsPath, item.filename))
        end

        if item.fileattr and item.fileattr == 0 then
            ParaIO.DeleteFile(format("%s/%s", userworldsPath, item.filename))
        end
    end
end
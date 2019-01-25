--[[
Title: Explorer App Page
Author(s):  big
Date: 2019.01.21
Place: Foshan
use the lib:
------------------------------------------------------------
local MainPage = NPL.load("(gl)Mod/ExplorerApp/components/MainPage.lua")
------------------------------------------------------------
]]
local Screen = commonlib.gettable("System.Windows.Screen")

local Store = NPL.load("(gl)Mod/WorldShare/store/Store.lua")
local Utils = NPL.load("(gl)Mod/WorldShare/helper/Utils.lua")
local Projects = NPL.load("(gl)Mod/WorldShare/service/KeepworkService/Projects.lua")
local Password = NPL.load("./Password/Password.lua")
local GameOver = NPL.load("./GameProcess/GameOver/GameOver.lua")
local TimeUp = NPL.load('./GameProcess/TimeUp/TimeUp.lua')
local ProactiveEnd = NPL.load('./GameProcess/ProactiveEnd/ProactiveEnd.lua')
local Wallet = NPL.load('./database/Wallet.lua')

local MainPage = NPL.export()

MainPage.categorySelected = 1
MainPage.categoryTree = {
    {value = L'精选'},
    {value = L'单人'},
    {value = L'双人'},
    {value = L'对战'},
    {value = L'动画'},
    {value = L'收藏'}
}

function MainPage:ShowPage()
	local params = Utils:ShowWindow(0, 0, "Mod/ExplorerApp/components/MainPage.html", "Mod.ExplorerApp.MainPage", 0, 0, "_fi", false)

    local MainPagePage = Store:Get('page/MainPage')

    if MainPagePage then
        MainPagePage:GetNode('categoryTree'):SetAttribute('DataSource', self.categoryTree)
        MainPage:SetWorkdsTree()
    end

	Screen:Connect("sizeChanged", MainPage, MainPage.OnScreenSizeChange, "UniqueConnection")
    MainPage.OnScreenSizeChange()
end

function MainPage:SetPage()
	Store:Set("page/MainPage", document:GetPageCtrl())
end

function MainPage:Refresh(times)
    local MainPagePage = Store:Get('page/MainPage')

    if MainPagePage then
        MainPagePage:Refresh(times or 0.01)
    end
end

function MainPage:Close()
    local MainPagePage = Store:Get('page/MainPage')

    if MainPagePage then
        MainPagePage:CloseWindow()
    end
end

function MainPage.OnScreenSizeChange()
	local MainPage = Store:Get('page/MainPage')

    if (not MainPage) then
        return false
    end

    local height = math.floor(Screen:GetHeight())
    local width = math.floor(Screen:GetWidth())

    local areaNode = MainPage:GetNode("area")
    areaNode:SetCssStyle('height', height)
    areaNode:SetCssStyle('width', width)
    
    local stripNode = MainPage:GetNode("strip")
    stripNode:SetCssStyle('margin-left', (width - 960) / 2)

    local areaContentNode = MainPage:GetNode("area_content")
    areaContentNode:SetCssStyle('height', (height - 45))
    areaContentNode:SetCssStyle('margin-left', (width - 960) / 2)

    MainPage:Refresh(0)
end

function MainPage:SetWorkdsTree(index)
    local MainPage = Store:Get('page/MainPage')

    if (not MainPage) then
        return false
    end

    if not index then
        index = 1
    end

    local filter = {"paracraft专属", self.categoryTree[index].value}

    Projects:GetProjects(filter, function(data, err)
        if not data or not data.rows then
            return false
        end

        self.categorySelected = index
        MainPage:GetNode('worksTree'):SetAttribute('DataSource', data.rows)
        self:Refresh()
    end)
end

function MainPage:SetCoins()
    Password:ShowPage()
end

function MainPage:SelectProject()
    ProactiveEnd:ShowPage()
end
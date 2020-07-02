--[[
Title: third party login
Author(s):  big
Date: 2020.06.01
City: Foshan
Desc: 
use the lib:
------------------------------------------------------------
local ThirdPartyLogin = NPL.load("(gl)Mod/WorldShare/cellar/LoginModal/ThirdPartyLogin.lua")
ThirdPartyLogin:Init(type)
------------------------------------------------------------
]]

-- service
local KeepworkService = NPL.load("(gl)Mod/WorldShare/service/KeepworkService.lua")
local KeepworkServiceSession = NPL.load("(gl)Mod/WorldShare/service/KeepworkService/Session.lua")

local ThirdPartyLogin = NPL.export()

function ThirdPartyLogin:Init(thirdPartyType, callback)
    if System.os.GetPlatform() ~= 'win32' and System.os.GetPlatform() ~= 'mac' then
        _guihelper.MessageBox(L"操作不支持此系统")
        return false
    end

    self.thirdPartyType = thirdPartyType
    self.callback = callback

    local params = Mod.WorldShare.Utils.ShowWindow(400, 450, "Mod/WorldShare/cellar/LoginModal/ThirdPartyLogin.html", "ThirdPartyLogin", nil, nil, nil, nil, 6)

    params._page:CallMethod("nplbrowser_instance", "SetVisible", true)
    params._page.OnClose = function()
        Mod.WorldShare.Store:Remove('page/ThirdPartyLogin')
        params._page:CallMethod("nplbrowser_instance", "SetVisible", false)
        Mod.WorldShare.Store:Unsubscribe("user/SetThirdPartyLoginAuthinfo")
    end

    Mod.WorldShare.Store:Subscribe("user/SetThirdPartyLoginAuthinfo", function()
        local authType = Mod.WorldShare.Store:Get("user/authType")
        local authCode = Mod.WorldShare.Store:Get("user/authCode")

        KeepworkServiceSession:CheckOauthUserExisted(authType, authCode, function(bExisted, data)
            params._page:CloseWindow()

            if bExisted then
                Mod.WorldShare.Store:Set("user/token", data.token)

                if type(self.callback) == "function" then
                    self.callback()
                end
            else
                if data and data.token then
                    Mod.WorldShare.Store:Set("user/authToken", data.token)
                else
                    Mod.WorldShare.Store:Remove("user/authToken")
                end

                Mod.WorldShare.MsgBox:Dialog(
                    "NoThirdPartyAccountNotice",
                    L"检测到该第三方账号还未绑定到账号，请绑定到已有账号或者新建账号进行绑定",
                    {
                        Title = L"补充账号信息",
                        Yes = L"绑定到已有账号",
                        No = L"新建账号并绑定"
                    },
                    function(res)
                        if res and res == _guihelper.DialogResult.Yes then
                            self:ShowCreateOrBindThirdPartyAccountPage("bind")
                        end

                        if res and res == _guihelper.DialogResult.No then
                            self:ShowCreateOrBindThirdPartyAccountPage("create")
                        end
                    end,
                    _guihelper.MessageBoxButtons.YesNo,
                    {
                        Yes = {
                            marginLeft = "40px",
                            width = "120px"
                        },
                        No = {
                            width = "120px"
                        }
                    }
                )

                return false
            end
        end)
    end)
end

function ThirdPartyLogin:GetUrl()
    local redirect_uri = Mod.WorldShare.Utils.EncodeURIComponent(KeepworkService:GetKeepworkUrl() .. '/p/third-login/')
    local sysTag = ''

    if System.os.GetPlatform() == 'win32' then
        sysTag = "WIN32"
    elseif System.os.GetPlatform() == 'mac' then
        sysTag = "MAC"
    end

    if self.thirdPartyType == 'WECHAT' then
        local clientId = KeepworkServiceSession:GetOauthClientId("WECHAT")
        local state = "WECHAT|" .. sysTag .. "|8099|" .. System.Encoding.guid.uuid()

        return
            format(
                "https://open.weixin.qq.com/connect/qrconnect?appid=%s&redirect_uri=%s&response_type=code&scope=snsapi_login&state=%s#wechat_redirect",
                clientId,
                redirect_uri,
                state
            )
    end

    if self.thirdPartyType == "QQ" then
        local clientId = KeepworkServiceSession:GetOauthClientId("QQ")
        local state = "QQ|" .. sysTag .. "|8099|" .. System.Encoding.guid.uuid()

        return 
            format(
                "https://graph.qq.com/oauth2.0/authorize?response_type=code&client_id=%s&redirect_uri=%s&state=%s",
                clientId,
                redirect_uri,
                state
            )
    end

    return ""
end

function ThirdPartyLogin:ShowCreateOrBindThirdPartyAccountPage(method)
    Mod.WorldShare.Utils.ShowWindow(400, 300, "Mod/WorldShare/cellar/LoginModal/CreateOrBindThirdPartyAccount.html?method=" .. (method or ""), "CreateOrBindThirdPartyAccount")
end

function ThirdPartyLogin:RegisterAndBind(account, password, authToken)
    KeepworkServiceSession:RegisterAndBindThirdPartyAccount(account, password, authToken, function(state)
        local CreateOrBindThirdPartyAccountPage = Mod.WorldShare.Store:Get("page/CreateOrBindThirdPartyAccount")

        if CreateOrBindThirdPartyAccountPage then
            CreateOrBindThirdPartyAccountPage:CloseWindow()
        end

        if not state then
            GameLogic.AddBBS(nil, L"未知错误", 5000, "0 255 0")
            return false
        end

        if state.id then
            if state.code then
                GameLogic.AddBBS(nil, format("%s%s(%d)", L"错误信息：", state.message or "", state.code or 0), 5000, "255 0 0")
            else
                -- register success
                -- OnKeepWorkLogin
                GameLogic.GetFilters():apply_filters("OnKeepWorkLogin", true)

                GameLogic.AddBBS(nil, L"注册成功", 5000, "0 255 0")
            end

            return true
        end

        GameLogic.AddBBS(nil, format("%s%s(%d)", L"注册失败，错误信息：", state.message or "", state.code or 0), 5000, "255 0 0")
    end)
end

function ThirdPartyLogin:LoginAndBind()

end
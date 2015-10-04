-----------------------------------------------------------------------------------------------
-- Client Lua Script for WSRPHousing
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "GameLib"
require "Unit"
require "ICCommLib"
require "ICComm"
require "XmlDoc"
require "ChatSystemLib"
require "HousingLib"
 
-----------------------------------------------------------------------------------------------
-- WSRPHousing Module Definition
-----------------------------------------------------------------------------------------------
local WSRPHousing = {} 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local ktStyles = {
	title = { color = "UI_TextHoloTitle", font = "CRB_HeaderLarge", align = "Center" },
	header = { color = "UI_TextHoloTitle", font = "CRB_InterfaceMedium_BB", align = "Left" },
	content = { color = "UI_BtnTextHoloNormal", font = "CRB_InterfaceMedium", align = "Left" },
	rules = {color = "UI_TextHoloTitle", font = "CRB_InterfaceMedium_BB", align = "Center" },
	callout = {color = "UI_WindowYellow", font = "CRB_InterfaceLarge_BBO", align = "Left" },
}
local kstrAnnounceTitle = "You are creating an announcement for the plot: %s"

local ktRealmChannel = {
	Jabbit = "LFRP",
	Entity = "WSRP",
}

local function strsplit(sep, str)
		local sep, fields = sep or ":", {}
		local pattern = string.format("([^%s]+)", sep)
		string.gsub(str ,pattern, function(c) fields[#fields+1] = c end)
		return fields
end

local kstrChatAnnounce = "[WSRP Housing] %s: %s"
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function WSRPHousing:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
	-- initialize variables here
	self.arRealmList = {}
    self.bAnimate = true
	self.tTickerContents = {}
	self.tAnnouncements = {}
	self.tMyAnnounce = {}
	
    return o
end

function WSRPHousing:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
		"OneVersion",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

 function WSRPHousing:OnDependencyError(strDep, strError)
	-- if you don't care about this dependency, return true.
	if strDep == "OneVersion" then
		return true
	end
	return false
end
-----------------------------------------------------------------------------------------------
-- WSRPHousing OnLoad
-----------------------------------------------------------------------------------------------
function WSRPHousing:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("WSRPHousing.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- WSRPHousing OnDocLoaded
-----------------------------------------------------------------------------------------------
function WSRPHousing:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "WSRPHousingForm", nil, self)
		Apollo.LoadSprites("WSRPHousingSprites.xml","WSRPHousingSprites")
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)
		self.wndMain:FindChild("wndLogo"):SetSprite("WSRPHousingSprites:Logo")
		self.wndAnnounce = self.wndMain:FindChild("wndAnnounce")
		self.wndAnnounce:FindChild("ebAnnounceText"):SetMaxTextLength(150)
		self.wndTicker = self.wndMain:FindChild("wndTicker")
		self.wndTicker:SetTickerSpeed(75)

		-- Register handlers for events, slash commands and timer, etc.
		Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded",	"OnInterfaceMenuLoaded", self)
		Apollo.RegisterEventHandler("WSRPHousing_InterfaceMenu",	"OnWSRPHousingInterfaceMenu", self)
		Apollo.RegisterEventHandler("WSRPHousing_UpdateAnouncement",	"OnAnnouncementUpdate", self)
		Apollo.RegisterEventHandler("GenericEvent_PlayerCampStart", "OnLogOut", self)
		Apollo.RegisterEventHandler("GenericEvent_PlayerExitStart", "OnLogOut", self)
		
		Apollo.RegisterSlashCommand("wsrphouse", "OnWSRPHousingOn", self)
		-- Do additional Addon initialization here
		self.tmrJoinChannel = ApolloTimer.Create(5.0, true, "OnJoinChannelTimer", self)
	end
end

function WSRPHousing:OnLogOut()
	Print("Log Out Triggered")
end


function WSRPHousing:OnJoinChannelTimer()
	--Print("Join Timer triggering")
	self.chnWSRPHousing = ICCommLib.JoinChannel("WSRPHousing", ICCommLib.CodeEnumICCommChannelType.Global)
	if self.chnWSRPHousing:IsReady() then
		--Print("Channel created, setting join result function.")
		--self.chnWSRPHousing:SetJoinResultFunction("OnJoinChannel", self)
		self.chnWSRPHousing:SetReceivedMessageFunction("OnMessageReceived", self)
		self.chnWSRPHousing:SetSendMessageResultFunction("OnMessageSent", self)
		self.tmrJoinChannel:Stop()
	end

end

function WSRPHousing:OnMessageReceived(channel, strMessage, idMessage)
	--Print("Message Received.")
	--"SenderName|PlotName|Message"
	local tMessage = strsplit("|", strMessage)
	if tMessage[2] == "CLEAR" then
		self:ClearReceived(tMessage)
	else
		self:AnnounceReceived(tMessage)
	end
end

function WSRPHousing:OnMessageSent(iccomm, eResult, idMessage)
	if eResult == ICCommLib.CodeEnumICCommMessageResult.Sent then
		--Print("Message Sent Correctly.")
	elseif eResult == ICCommLib.CodeEnumICCommMessageResult.NotInChannel then
		Apollo.AddAddonErrorText(self, "Not in Channel.")
	elseif eResult == ICCommLib.CodeEnumICCommMessageResult.Throttled then
		Apollo.AddAddonErrorText(self, "Message Throttled.")
	end
end

function WSRPHousing:OnJoinChannel(iccomm, eResult)
	if eResult == ICCommLib.CodeEnumICCommJoinResult.Join then
		self.tmrJoinChannel:Stop()
		self.chnWSRPHousing:SetReceivedMessageFunction("OnMessageReceived", self)
		self.chnWSRPHousing:SetSendMessageResultFunction("OnMessageSent", self)
	end
end

function WSRPHousing:SendAnnounce()
	local strMessage = string.format("%s|%s|%s", unpack(self.tMyAnnounce))
	self.chnWSRPHousing:SendMessage(strMessage)
	if self.bChatAnnounce == true then
		self.chnRPChat:Send(string.format(kstrChatAnnounce, self.tMyAnnounce[2], self.tMyAnnounce[3]))
	end
end

function WSRPHousing:SendClear()
	local strMessage = string.format("%s|CLEAR", self.strName)
	self.tMyAnnounce = nil
	self.tMyAnnounce = {}
	Event_FireGenericEvent("WSRPHousing_UpdateAnouncement")
	self.chnWSRPHousing:SendMessage(strMessage)
end

function WSRPHousing:AnnounceReceived(tNewAnnouncement)
	if not self.tAnnouncements then self.tAnnouncements = {} end
	for i,v in pairs(self.tAnnouncements) do
		if v[1] == tNewAnnouncement[1] then
			self.tAnnouncements[i] = tNewAnnouncement
			Event_FireGenericEvent("WSRPHousing_UpdateAnouncement")
			return
		end
	end
	table.insert(self.tAnnouncements, tNewAnnouncement)
	Event_FireGenericEvent("WSRPHousing_UpdateAnouncement")
	Event_FireGenericEvent("InterfaceMenuList_AlertAddOn", "WSRP Housing Directory", {true, " Announcements Updated", #self.tAnnouncements})
end

function WSRPHousing:ClearReceived(tMessage)
	for i,v in pairs(self.tAnnouncements) do
		if v[1] == tMessage[1] then
			table.remove(self.tAnnouncements, i)
			Event_FireGenericEvent("WSRPHousing_UpdateAnouncement")
			return
		end
	end
end

function WSRPHousing:OnAnnouncementUpdate()
		for i,v in pairs(self.tTickerContents) do
			v:Destroy()
		end
	
		for i, v in pairs(self.tAnnouncements) do
				local wnd = Apollo.LoadForm(self.xmlDoc, "TickerContentForm", self.wndTicker, self)
				local xmlContent = XmlDoc.new()
				xmlContent:AddLine(v[2]..": ", "UI_TextHoloTitle", "CRB_InterfaceLarge_BBO")
				xmlContent:AppendText(v[3], "UI_BtnTextHoloNormal", "CRB_InterfaceLarge_BB")
				wnd:SetDoc(xmlContent)
				local iNumChars = string.len(v[3]) + string.len(v[2])
				local iWidth = iNumChars / 10 * 110
				wnd:SetAnchorOffsets(0,0,iWidth,0)
				self.wndTicker:AddTickerForm(wnd)
				table.insert(self.tTickerContents, wnd)
		end
		if #self.tMyAnnounce > 0 then
				local wnd = Apollo.LoadForm(self.xmlDoc, "TickerContentForm", self.wndTicker, self)
				local xmlContent = XmlDoc.new()
				xmlContent:AddLine(self.tMyAnnounce[2]..": ", "UI_TextHoloTitle", "CRB_InterfaceLarge_BBO")
				xmlContent:AppendText(self.tMyAnnounce[3], "UI_BtnTextHoloNormal", "CRB_InterfaceLarge_BB")
				wnd:SetDoc(xmlContent)
				local iNumChars = string.len(self.tMyAnnounce[3]) + string.len(self.tMyAnnounce[2])
				local iWidth = iNumChars / 10 * 110
				wnd:SetAnchorOffsets(0,0,iWidth,0)
				self.wndTicker:AddTickerForm(wnd)
				table.insert(self.tTickerContents, wnd)
		end
end

-----------------------------------------------------------------------------------------------
-- Save and Restore Data
-----------------------------------------------------------------------------------------------
function WSRPHousing:OnSave(eLevel)
	-- This example uses account level saves.
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then
	-- Set your variables into tData
		return { bAnimate = self.bAnimate }
	end
end

function WSRPHousing:OnRestore(eLevel, tData)
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then
		-- Set your reference for the saved variables
		if tData then
			self.bAnimate = tData.bAnimate
		end
	end
end

-----------------------------------------------------------------------------------------------
-- InterfaceMenu Button
-----------------------------------------------------------------------------------------------
function WSRPHousing:OnInterfaceMenuLoaded()
	local tData = {"WSRPHousing_InterfaceMenu", "","WSRPHousingSprites:Icon"}
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "WSRP Housing Directory" , tData)
	local iMaj, iMin, iPatch = unpack(strsplit(".", XmlDoc.CreateFromFile("toc.xml"):ToTable().Version))
	Event_FireGenericEvent("OneVersion_ReportAddonInfo", "WSRPHousing", tonumber(iMaj), tonumber(iMin), tonumber(iPatch))
end
--btnAnimate
function WSRPHousing:OnWSRPHousingInterfaceMenu()
	-- Define what happens here.
	self:OnWSRPHousingOn()
end

-----------------------------------------------------------------------------------------------
-- WSRPHousing Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

function WSRPHousing:LoadData(strRealmName)

	local strFaction
	for i,v in pairs(Unit.CodeEnumFaction) do
		if v == GameLib.GetPlayerUnit():GetFaction() then
			strFaction = i
			break
		end
	end
	--ExilesPlayer, DominionPlayer
	self.strRealmFac = string.format("%s%s", strRealmName, strFaction)
	local tDirectory = dofile(string.match(Apollo.GetAssetFolder(), "(.-)[\\/][Aa][Dd][Dd][Oo][Nn][Ss]") .. "\\Addons\\WSRPHousing\\Lists\\".. self.strRealmFac .. ".lua")
	local wndList = self.wndMain:FindChild("wndGrid")
	for i,v in pairs(tDirectory) do
		wndList:AddRow(v.title)
	end
	
	return tDirectory
end

function WSRPHousing:CreateEntry(iIndex)
	local tEntry = self.tDirectory[iIndex]
	local xmlEntry = XmlDoc.new()
	xmlEntry:AddLine(tEntry.title, ktStyles.title.color, ktStyles.title.font, ktStyles.title.align)
	xmlEntry:AddLine("Owner: ", ktStyles.header.color, ktStyles.header.font, ktStyles.header.align)
	xmlEntry:AppendText(tEntry.owner, ktStyles.content.color, ktStyles.content.font, {Align = ktStyles.content.align})
	xmlEntry:AppendText("    [Visit]", ktStyles.callout.color, ktStyles.callout.font, { owner = tEntry.owner,  BGColor  = "ffffffff"}, "Visit")
	xmlEntry:AddLine("Hours: ", ktStyles.header.color, ktStyles.header.font, ktStyles.header.align)
	xmlEntry:AppendText(tEntry.hours, ktStyles.content.color, ktStyles.content.font, {Align = ktStyles.content.align})
	xmlEntry:AddLine("Staff: ", ktStyles.header.color, ktStyles.header.font, ktStyles.header.align)
	local arStaff = strsplit(",", tEntry.staff)
	for i,v in pairs(arStaff) do
		local strSep = ", "
		if i == #arStaff then
			strSep = ""
		end
		if v == self.strName then
			xmlEntry:AppendText(v.." ", ktStyles.content.color, ktStyles.content.font, { player = v}, "Staff" )
			xmlEntry:AppendText("[Make Announcement]", ktStyles.callout.color, ktStyles.callout.font, { player = v, title = tEntry.title}, "Announce" )
			xmlEntry:AppendText(strSep, ktStyles.content.color, ktStyles.content.font)

		else
			xmlEntry:AppendText(v..strSep, ktStyles.content.color, ktStyles.content.font, { player = v}, "Staff" )	
		end

	end
	xmlEntry:AddLine("________________________________________________________________",  ktStyles.rules.color, ktStyles.rules.font, ktStyles.rules.align)
	local arDescription = strsplit("\n", tEntry.description)
	for i,v in pairs(arDescription) do
		xmlEntry:AddLine("    "..v, ktStyles.content.color, ktStyles.content.font, ktStyles.content.align)
	end
	return xmlEntry
end
-----------------------------------------------------------------------------------------------
-- WSRPHousingForm Functions
-----------------------------------------------------------------------------------------------
function WSRPHousing:OnCancel()
	Event_FireGenericEvent("InterfaceMenuList_AlertAddOn", "WSRP Housing Directory", {false, nil, nil})
	self.wndMain:Close() -- hide the window
end

function WSRPHousing:OnSelectionChanged( wndHandler, wndControl, iRow, iCol)
	local xmlEntry = self:CreateEntry(iRow)
	local wndHolo = self.wndMain:FindChild("wndHoloDisplay")
	local wndMarkup = wndHolo:FindChild("wndMarkup")
	wndMarkup:SetDoc(xmlEntry)
	local wndLogo = self.wndMain:FindChild("wndLogo")
	if wndLogo:IsShown() then
		wndLogo:Show(false, true)
	end
	if self.bAnimate == true then
			wndHolo:SetAnchorOffsets(220, 136, 669, 176)
			local tLoc = WindowLocation.new({ fPoints = { 0, 0, 0, 0 }, nOffsets = { 220, 136, 669, 770 }})
			wndHolo:TransitionMove(tLoc, 1)
			wndMarkup:RecalculateContentExtents()
			wndMarkup:SetVScrollPos(0)
			--wndMarkup:BeginDoogie(500)
	else
			wndHolo:SetAnchorOffsets(220, 136, 669, 770)
			wndMarkup:RecalculateContentExtents()
			wndMarkup:SetVScrollPos(0)
	end
end

function WSRPHousing:OnWSRPHousingOn(...)
	self.wndMain:Show(not self.wndMain:IsShown())
	self.wndMain:FindChild("btnAnimate"):SetCheck(self.bAnimate)
	self.strName = GameLib.GetPlayerUnit():GetName()
	if not	self.tDirectory then
		self.tDirectory = self:LoadData(GameLib.GetRealmName())
	end
	if self.chnRPChat == nil then
		local tChannels = ChatSystemLib.GetChannels()
		for i,v in pairs(tChannels) do
			local strChanName = v:GetName() 
			if v:IsCustom() == true and strChanName == ktRealmChannel[GameLib.GetRealmName()] then
				self.chnRPChat = v
			end
		end
	end
	--Print("Chat Channel Identified: "..self.chnRPChat:GetName())
	Event_FireGenericEvent("WSRPHousing_UpdateAnouncement")
end

function WSRPHousing:OnNodeClick(wndHandler, wndControl, strNode, tAttributes, eMouseButton)
	if strNode == "Visit" and eMouseButton == GameLib.CodeEnumInputMouse.Left then
		self:Visit(tAttributes)
	elseif strNode == "Staff" and eMouseButton == GameLib.CodeEnumInputMouse.Left then
		self:StaffWho(tAttributes)
	elseif strNode == "Announce" and eMouseButton == GameLib.CodeEnumInputMouse.Left then
		self:ShowAnnounce(tAttributes)
	end
end

function WSRPHousing:StaffWho(tAttributes)
	local tNameParts = strsplit(" ", tAttributes.player)
	ChatSystemLib.Command( "/who ".. tNameParts[1])
end

function WSRPHousing:Visit(tAttributes)
	HousingLib.RequestVisitPlayer(tAttributes.owner)
end

function WSRPHousing:ShowAnnounce(tAttributes)
	self.wndAnnounce:FindChild("wndInfo"):SetText(string.format(kstrAnnounceTitle, tAttributes.title))
	self.wndAnnounce:SetData(tAttributes.title)
	if self.bAnimate then
		local tLoc = WindowLocation.new({ fPoints = {1,1,1,1}, nOffsets = {-470, -403, 0, 0}})
		self.wndAnnounce:TransitionMove(tLoc,1)
	else
		self.wndAnnounce:SetAnchorOffsets(-470, -403, 0, 0)
	end
end

function WSRPHousing:HideAnnounce()
	if self.bAnimate then
		local tLoc = WindowLocation.new({ fPoints = {1,1,1,1}, nOffsets = {-470, -16, 0, 0}})
		self.wndAnnounce:TransitionMove(tLoc,1)
	else
		self.wndAnnounce:SetAnchorOffsets(-470, -16, 0, 0)
	end
	
end

function WSRPHousing:OnAnimateToggle( wndHandler, wndControl, eMouseButton )
	self.bAnimate = wndControl:IsChecked()
	self.wndMain:FindChild("wndHoloDisplay:wndMarkup"):StopDoogie()
end

function WSRPHousing:OnGoHomeClick( wndHandler, wndControl, eMouseButton )
	if HousingLib.IsHousingWorld() == true then 
		HousingLib.RequestTakeMeHome()
	end
end

function WSRPHousing:OnAnnounce( wndHandler, wndControl, eMouseButton )
	local strMessage = self.wndAnnounce:FindChild("ebAnnounceText"):GetText()
	local nTimeBetweenRepeat = self.wndAnnounce:FindChild("sldrTime"):GetValue()
	self.tMyAnnounce = {self.strName, self.wndAnnounce:GetData(), strMessage}
	self.tmrRepeatMessage = ApolloTimer.Create(nTimeBetweenRepeat * 60, true, "SendAnnounce", self)
	self:SendAnnounce()
end

function WSRPHousing:OnClearAnnounce( wndHandler, wndControl, eMouseButton )
	if self.tMyAnnounce == nil then return end
	self.tMyAnnounce = nil
	if self.tmrRepeatMessage then
		self.tmrRepeatMessage:Stop()
	end
	self.tmrRepeatMessage = nil
	self.wndAnnounce:FindChild("ebAnnounceText"):SetText("")
	self.wndAnnounce:FindChild("sldrTime"):SetValue(2)
	self:SendClear()
end

function WSRPHousing:OnTimeChange( wndHandler, wndControl, fNewValue, fOldValue )

end

function WSRPHousing:OnChatAnnounceCheck( wndHandler, wndControl, eMouseButton )
	self.bChatAnnounce = wndControl:IsChecked()
end

-----------------------------------------------------------------------------------------------
-- WSRPHousing Instance
-----------------------------------------------------------------------------------------------
local WSRPHousingInst = WSRPHousing:new()
WSRPHousingInst:Init()
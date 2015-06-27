-----------------------------------------------------------------------------------------------
-- Client Lua Script for WSRPHousing
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "GameLib"
require "Unit"
 
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
	rules = {color = "UI_TextHoloTitle", font = "CRB_InterfaceMedium_BB", align = "Center" }
}

local function strsplit(sep, str)
		local sep, fields = sep or ":", {}
		local pattern = string.format("([^%s]+)", sep)
		string.gsub(str ,pattern, function(c) fields[#fields+1] = c end)
		return fields
end

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
		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded",	"OnInterfaceMenuLoaded", self)
		Apollo.RegisterEventHandler("WSRPHousing_InterfaceMenu",	"OnWSRPHousingInterfaceMenu", self)
		Apollo.RegisterSlashCommand("wsrphouse", "OnWSRPHousingOn", self)
		-- Do additional Addon initialization here
	end
end

-----------------------------------------------------------------------------------------------
-- Save and Restore Data
-----------------------------------------------------------------------------------------------
function WSRPHousing:OnSave(eLevel)
	local tSavedData = {}
	-- This example uses account level saves.
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then
	-- Set your variables into tData
		tSavedData.bAnimate = bAnimate
	end
	
	return tSavedData
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
		--Print(v..": "..i)
		if v == GameLib.GetPlayerUnit():GetFaction() then
			strFaction = i
			break
		end
	end
	--ExilesPlayer, DominionPlayer
	local strRealmFac = string.format("%s%s", strRealmName, strFaction)
	local tDirectory = dofile(string.match(Apollo.GetAssetFolder(), "(.-)[\\/][Aa][Dd][Dd][Oo][Nn][Ss]") .. "\\Addons\\WSRPHousing\\Lists\\".. strRealmFac .. ".lua")
	Apollo.LoadSprites(strRealmFac .. ".xml", strRealmFac )
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
	xmlEntry:AppendText("    [Visit]", "UI_WindowYellow","CRB_InterfaceLarge_BBO", { owner = tEntry.owner,  BGColor  = "ffffffff"}, "Visit")
	xmlEntry:AddLine("Hours: ", ktStyles.header.color, ktStyles.header.font, ktStyles.header.align)
	xmlEntry:AppendText(tEntry.hours, ktStyles.content.color, ktStyles.content.font, {Align = ktStyles.content.align})
	xmlEntry:AddLine("Staff: ", ktStyles.header.color, ktStyles.header.font, ktStyles.header.align)
	local arStaff = strsplit(",", tEntry.staff)
	for i,v in pairs(arStaff) do
		local strSep = ", "
		if i == #arStaff then
			strSep = ""
		end
		xmlEntry:AppendText(v..strSep, ktStyles.content.color, ktStyles.content.font, { player = v}, "Staff" )
	end
	xmlEntry:AddLine("________________________________________________________________",  ktStyles.rules.color, ktStyles.rules.font, ktStyles.rules.align)
	local arDescription = strsplit("\n", tEntry.description)
	for i,v in pairs(arDescription) do
		xmlEntry:AddLine("    "..v, ktStyles.content.color, ktStyles.content.font, ktStyles.content.align)
	end
	if tEntry.screenshots then
		local tScreenshots = strsplit(",", tEntry.screenshots)
		xmlEntry:AddLine("------------------------------------------------------------------------",  ktStyles.rules.color, ktStyles.rules.font, ktStyles.rules.align)
		for i,v in pairs(tScreenshots) do
			xmlEntry:AddLine("", ktStyles.rules.color, ktStyles.rules.font, ktStyles.rules.align)
			xmlEntry:AppendImage(v, 256, 256)
			xmlEntry:AddLine("------------------------------------------------------------------------",  ktStyles.rules.color, ktStyles.rules.font, ktStyles.rules.align)
		end
	end
	return xmlEntry
end

-----------------------------------------------------------------------------------------------
-- WSRPHousingForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function WSRPHousing:OnOK()
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function WSRPHousing:OnCancel()
	self.wndMain:Close() -- hide the window
end

function WSRPHousing:OnSelectionChanged( wndHandler, wndControl, iRow, iCol)
	local xmlEntry = self:CreateEntry(iRow)
	local wndHolo = self.wndMain:FindChild("wndHoloDisplay")
	local wndMarkup = wndHolo:FindChild("wndMarkup")
	wndMarkup:SetDoc(xmlEntry)
	local wndLogo = self.wndMain:FindChild("wndLogo")
	if wndLogo:IsShown() then
		wndLogo:Show(false, false)
	end	
	if self.bAnimate == true then
			wndHolo:SetAnchorOffsets(220, 72, 669, 112)
			local tLoc = WindowLocation.new({ fPoints = { 0, 0, 0, 0 }, nOffsets = { 220, 72, 669, 770 }})
			wndHolo:TransitionMove(tLoc, 1)
			wndMarkup:RecalculateContentExtents()
			wndMarkup:SetVScrollPos(0)
			wndMarkup:BeginDoogie(500)
	else
			wndHolo:SetAnchorOffsets(220, 72, 669, 770)
			wndMarkup:RecalculateContentExtents()
			wndMarkup:SetVScrollPos(0)
	end
end

function WSRPHousing:OnWSRPHousingOn(...)
	self.wndMain:Show(not self.wndMain:IsShown())
	self.wndMain:FindChild("btnAnimate"):SetCheck(self.bAnimate)
	if not	self.tDirectory then
		self.tDirectory = self:LoadData(GameLib.GetRealmName())
	end
end

function WSRPHousing:OnNodeClick(wndHandler, wndControl, strNode, tAttributes, eMouseButton)
	if strNode == "Visit" and eMouseButton == GameLib.CodeEnumInputMouse.Left then
		self:Visit(tAttributes)
	elseif strNode == "Staff" and eMouseButton == GameLib.CodeEnumInputMouse.Left then
		self:StaffWho(tAttributes)
	end
end

function WSRPHousing:StaffWho(tAttributes)
	local tNameParts = strsplit(" ", tAttributes.player)
	ChatSystemLib.Command( "/who ".. tNameParts[1])
end

function WSRPHousing:Visit(tAttributes)
	HousingLib.RequestVisitPlayer(tAttributes.owner)
end

function WSRPHousing:OnAnimateToggle( wndHandler, wndControl, eMouseButton )
	self.bAnimate = wndControl:IsChecked()
	self.wndMain:FindChild("wndHoloDisplay:wndMarkup"):StopDoogie()
end

-----------------------------------------------------------------------------------------------
-- WSRPHousing Instance
-----------------------------------------------------------------------------------------------
local WSRPHousingInst = WSRPHousing:new()
WSRPHousingInst:Init()
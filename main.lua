local LootTable = LibStub("AceAddon-3.0"):NewAddon("LootTable", "AceConsole-3.0", "AceEvent-3.0")
_G.LootTable = LootTable

--SLASH_LOOTTABLE1 = "/lt"
--SLASH_LOOTTABLE2 = "/loottable"
--SlashCmdList["LOOTTABLE"] = function(mgs)
--	lt_toggle()
--end

LootTable.db = {}

local console = LibStub("AceConsole-3.0")
local gui = LibStub("AceGUI-3.0")
local event = LibStub("AceEvent-3.0")

local remoteItems = 0
local lootFrame = nil
local targetNPCID = nil
local targetName = nil

function LootTable:OnInitialize()
	-- Code that you want to run when the addon is first loaded goes here.
	LootTable:RegisterChatCommand("lt", "Chat_ToggleLootTable")
end
--The OnInitialize() method of your addon object is called by AceAddon when the addon is first loaded by the game client. It's a good time to do things like restore saved settings (see the info on AceConfig for more notes about that).

function LootTable:OnEnable()
    -- Called when the addon is enabled
	--GET_ITEM_INFO_RECEIVED
	LootTable:RegisterEvent("GET_ITEM_INFO_RECEIVED", "handle_remoteItemsReceived")
end

function LootTable:OnDisable()
    -- Called when the addon is disabled
	LootTable:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
	remoteItems = 0
	lootFrame = nil
	targetNPCID = nil
end

function LootTable:Chat_ToggleLootTable(input)
	lt_toggle()
end

function LootTable:handle_remoteItemsReceived()
	remoteItems = remoteItems - 1
	if (remoteItems <= 0) then
		remoteItems = 0
		if (lootFrame == nil) then
			return --no our receives?
		end
		local ret = checkItems(targetNPCID)
		if (ret == 0) then
			setLootText(targetNPCID)
		else
			--console:Print("Error while request ("..ret..")")
		end
	end
end

function lt_toggle()
	if (lootFrame ~= nil and remoteItems > 0) then
		return
	elseif (lootFrame ~= nil) then
		gui:Release(lootFrame)
		lootFrame = nil
	end

	targetName = UnitName("target")
	local guid = UnitGUID("target")
	
	if (guid == nil) then
		return
	end
	
	local type, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-",guid);
	
	local ret = checkItems(npc_id)
	if (ret >= 0) then
		if (ret > 0) then
			targetNPCID = npc_id
			lootFrame = gui:Create("Frame")
			lootFrame:SetStatusText("LootTable")
			lootFrame:SetTitle("Loot for "..targetName)
			lootFrame:SetCallback("OnClose", function(widget) 
				remoteItems = 0
				lootFrame = nil
				lbl_lootdesc = nil
				targetNPCID = nil
				gui:Release(widget) 
			end)
			lootFrame:SetLayout("Flow")
			lootFrame:SetWidth(200)
			lootFrame:SetHeight(150)
			lbl_lootdesc = gui:Create("Label")
			lbl_lootdesc:SetFullWidth(true)
			lbl_lootdesc:SetText("Loading...")
			lbl_lootdesc:SetFont("Fonts\\FRIZQT__.TTF", 16)
			lootFrame:AddChild(lbl_lootdesc)
		else
			setLootText(npc_id)
		end
		lootFrame:Show()
	else
		console:Print("|cffff0000"..targetName.." is not registered ["..npc_id.."]")
	end
end

-- if items have to be fetched from the servers returns 1
-- if no loot is present for npc_id returns -1
-- otherwise returns 0
function checkItems(npc_id)
	local lt = LootTable.db[npc_id]
	if (lt ~= nil) then
		for i,e in pairs(lt) do
			local itemname, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(tonumber(e["item"]))
			if (itemname == nil) then
				remoteItems = remoteItems + 1
			end
		end
		if (remoteItems > 0) then
			targetNPCID = npc_id
			return 1
		else
			return 0
		end
	else
		return -1
	end
end

function setLootText(npc_id)
	if (lootFrame ~= nil) then
		gui:Release(lootFrame)		-- remove loading window
		lootFrame = nil
	end
	local lt = LootTable.db[npc_id]
	if (lt ~= nil) then
		lootFrame = gui:Create("LootTableFrame")
		lootFrame:SetStatusText("LootTable")
		lootFrame:SetTitle("Loot for "..targetName)
		lootFrame:EnableResize(true)
		lootFrame:SetCallback("OnClose", function(widget) 
			remoteItems = 0
			lootFrame = nil
			lbl_lootdesc = nil
			targetNPCID = nil
			gui:Release(widget) 
		end)
		lootFrame:SetLayout("Flow")
		lootFrame:SetWidth(350)
		lootFrame:SetHeight(250)
		
		scrollcontainer = gui:Create("SimpleGroup")
		scrollcontainer:SetFullWidth(true)
		scrollcontainer:SetFullHeight(true) -- probably?
		scrollcontainer:SetLayout("Fill") -- important!

		lootFrame:AddChild(scrollcontainer)

		scroll = gui:Create("ScrollFrame")
		scroll:SetLayout("Flow") -- probably?
		scrollcontainer:AddChild(scroll)
		
		local lbl_npclink = gui:Create("InteractiveLabel")
		lbl_npclink:SetFullWidth(true)
		lbl_npclink:SetCallback("OnClick", function(self) 
			open_url("http://www.wowhead.com/npc="..npc_id)
		end)
		lbl_npclink:SetText("|cffffc800> wowhead.com "..npc_id)
		lbl_npclink:SetFont("Fonts\\FRIZQT__.TTF", 12)
		scroll:AddChild(lbl_npclink)
		
		table.sort(lt, function(a,b)
			if (a["chance"] == b["chance"]) then
				return a["item"] > b["item"]
			else 
				return a["chance"] > b["chance"]
			end
		end)
		
		for i,e in pairs(lt) do
			local itemname, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(tonumber(e["item"]))
			if (itemname ~= nil) then
				local lbl_lootdesc = gui:Create("InteractiveLabel")
				lbl_lootdesc:SetFullWidth(true)
				lbl_lootdesc:SetCallback("OnEnter", function(self) 
					GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
					GameTooltip:SetHyperlink(link)
					GameTooltip:Show()
				end)
				lbl_lootdesc:SetCallback("OnClick", function(self) 
					open_url(link)
				end)
				lbl_lootdesc:SetCallback("OnLeave", function(self)
					GameTooltip:Hide()
				end)
				lbl_lootdesc:SetText(e["chance"] .. "% for " .. link)
				lbl_lootdesc:SetFont("Fonts\\FRIZQT__.TTF", 12)
				scroll:AddChild(lbl_lootdesc)
			end
		end
		lootFrame:Show()
	else
		return -1
	end
end

function open_url(url)
	console:Print(url)
end
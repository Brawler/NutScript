AddCSLuaFile()

ENT.Type = "anim"
ENT.Name = "Container"
ENT.Author = "Chessnut and rebel1324"
ENT.Spawnable = false

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_lab/filecabinet02.mdl")
		self:SetNetVar("max", 10)
		self:SetNetVar("inv", {})
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physicsObject = self:GetPhysicsObject()

		if (IsValid(physicsObject)) then
			physicsObject:Wake()
		end
	end

	function ENT:Use(activator)
		netstream.Start(activator, "nut_ShowStorageMenu", self)
	end

	function ENT:UpdateInv(class, quantity, data)
		if (!nut.item.Get(class)) then
			return
		end

		local inventory = self:GetNetVar("inv")
		local oldInventory = inventory

		inventory = nut.util.StackInv(inventory, class, quantity, data)

		local weight, max = self:GetInvWeight()

		if (weight > max) then
			inventory = oldInventory
		else
			self:SetNetVar("inv", inventory)
		end
	end

	function ENT:GetItemsByClass(class)
		return self:GetNetVar("inv")[class] or {}
	end

	function ENT:GiveMoney(amount)
		local current = self:GetNetVar("money", 0)

		self:SetNetVar("money", current + amount)
	end

	function ENT:TakeMoney(amount)
		self:GiveMoney(-amount)
	end
	
	function ENT:KeyOpen( activator )
		if self.lock then
			for index, idat in pairs( activator:GetItemsByClass( "key_generic" )  ) do
				if idat.data.lock == self.lock then
					return true
				end
			end
		end
		return false
	end
	
	netstream.Hook( "nut_RequestLock", function(client, data)
		local entity = data[1]
		local classic = data[2]
		local password = data[3]
		if entity.world then return nut.util.Notify( nut.lang.Get( "lock_itsworld" )  , client) end
		if !client.nextLock or client.nextLock <= CurTime() then
			if entity.lock then return nut.util.Notify( nut.lang.Get( "lock_locked" )  , client) end
			
			if ( classic == 1 ) then
				local locknum = math.random( 1, 999999 )
				entity.lock = locknum
				entity.classic = true
				client:UpdateInv( "key_generic", 3, {
					lock = locknum
				} )
				client:UpdateInv( "classic_locker_1", -1 )
			elseif ( classic == 0 ) then
				entity.lock = password
				client:UpdateInv( "digital_locker_1", -1 )
			end	
			
			entity:SetNetVar( "locked", true )
			nut.util.Notify( nut.lang.Get( "lock_success" ) , client)	-- If couldn't found a key, Reject the request.
			entity:EmitSound( "doors/door_metal_thin_open1.wav" )
			client.nextLock = CurTime() + 10
		end
		
	end)
	
	netstream.Hook( "nut_VerifyPassword", function(client, data)
		local entity = data[1]
		local password = data[2]
		if entity.lock == password then
			netstream.Start(client, "nut_Storage", entity)
		else
			nut.util.Notify( nut.lang.Get( "lock_wrong" ), client)	
			entity:EmitSound( "doors/door_metal_thin_open1.wav" )
		end
	end)
	
	netstream.Hook("nut_RequestStorageMenu", function(client, entity)
		--** Request Storage Menu Enterance
		if entity.lock then --** Check if is locked or not
			if entity.classic then --** If the lock is classic lock
				if entity:KeyOpen( client ) then --** Search for the key.
					netstream.Start(client, "nut_Storage", entity)
				else
					nut.util.Notify( nut.lang.Get( "lock_try" ) , client)	-- If couldn't found a key, Reject the request.
					entity:EmitSound( "doors/door_metal_thin_open1.wav" )
					return
				end
			else
				--** If the lock is digital lock ( digit lock )
				netstream.Start(client, "nut_RequestPassword", entity)
			end
		else
			netstream.Start(client, "nut_Storage", entity)
		end
	end)
	
	netstream.Hook("nut_StorageUpdate", function(client, data)
		local entity = data[1]
		local class = data[2]
		local quantity = data[3]
		local data = data[4]
		local itemTable = nut.item.Get(class)
		
		if (itemTable and IsValid(entity) and entity:GetPos():Distance(client:GetPos()) <= 128) then
			if (itemTable.CanTransfer and itemTable:CanTransfer(client, data) == false) then
				return false
			end

			if (quantity > 0 and client:HasItem(class)) then
				local result = client:UpdateInv(class, -1, data)

				if (result) then
					entity:UpdateInv(class, 1, data)
				end
			elseif (entity:HasItem(class)) then
				local result = client:UpdateInv(class, 1, data)

				if (result) then
					entity:UpdateInv(class, -1, data)
				end
			end
		end
	end)

	netstream.Hook("nut_TransferMoney", function(client, data)
		local entity = data[1]
		local amount = data[2]

		amount = math.floor(amount)

		local amount2 = math.abs(amount)

		if (!IsValid(entity) or entity:GetPos():Distance(client:GetPos()) > 128) then
			return
		end

		if (client:HasMoney(amount) and amount > 0) then
			entity:GiveMoney(amount)
			client:TakeMoney(amount)
		elseif (entity:HasMoney(amount2)) then
			entity:TakeMoney(amount2)
			client:GiveMoney(amount2)
		end
	end)
	
	netstream.Hook("nut_Storage", function(client, entity)
		if client:IsAdmin() then
			netstream.Start(client, "nut_Storage", entity)
		end
	end)
else
	netstream.Hook("nut_Storage", function(entity)
		if (IsValid(entity)) then
			nut.schema.Call("ContainerOpened", entity)
			
			nut.gui.storage = vgui.Create("nut_Storage")
			nut.gui.storage:SetEntity(entity)

			entity:HookNetVar("inv", function()
				if (IsValid(nut.gui.storage) and nut.gui.storage:GetEntity() == entity) then
					nut.gui.storage:Reload()
				end
			end)

			entity:HookNetVar("money", function()
				if (IsValid(nut.gui.storage) and nut.gui.storage:GetEntity() == entity) then
					nut.gui.storage.money:SetText(entity:GetMoney())
					nut.gui.storage.money2:SetText(LocalPlayer():GetMoney())
				end
			end)

			nut.char.HookVar("money", "storageMoney", function()
				if (IsValid(nut.gui.storage) and nut.gui.storage:GetEntity() == entity) then
					nut.gui.storage.money2:SetText(LocalPlayer():GetMoney())
				end
			end)
		end
	end)
end

function ENT:GetInvWeight()
	local weight, maxWeight = 0, self:GetNetVar("max", nut.config.defaultInvWeight)
	local inventory = self:GetNetVar("inv")

	if (inventory) then
		for uniqueID, items in pairs(inventory) do
			local itemTable = nut.item.Get(uniqueID)

			if (itemTable) then
				local quantity = 0

				for k, v in pairs(items) do
					quantity = quantity + v.quantity
				end

				local addition = itemTable.weight * quantity

				if (itemTable.weight < 0) then
					maxWeight = maxWeight + addition
				else
					weight = weight + addition
				end
			end
		end
	end

	return weight, maxWeight
end

function ENT:HasMoney(amount)
	return self:GetNetVar("money", 0) >= amount
end

function ENT:HasItem(class, quantity)
	local amt = 0
	for k, v in pairs( self:GetItemsByClass(class) ) do
		amt = amt + v.quantity
	end
	return amt >= (quantity or 1)
end

function ENT:GetMoney()
	return self:GetNetVar("money", 0)
end
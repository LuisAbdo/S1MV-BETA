-- [ReceiptService] Unico ProcessReceipt do jogo. Idempotente: cada PurchaseId e
-- registrado no DataStore e nunca e entregue duas vezes.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")

local ReceiptService = {}
local handlers = {}
local store

function ReceiptService:Register(productId, fn)
	if productId and productId > 0 then handlers[productId] = fn end
end

function ReceiptService:Init()
	local ok, s = pcall(function() return DataStoreService:GetDataStore("Recibos_v1") end)
	if ok then store = s end
end

function ReceiptService:Start()
	MarketplaceService.ProcessReceipt = function(receipt)
		local key = tostring(receipt.PurchaseId)
		if store then
			local okGet, done = pcall(function() return store:GetAsync(key) end)
			if not okGet then return Enum.ProductPurchaseDecision.NotProcessedYet end
			if done then return Enum.ProductPurchaseDecision.PurchaseGranted end
		end
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local handler = handlers[receipt.ProductId]
		if not player or not handler then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local okRun, granted = pcall(handler, player, receipt)
		if not okRun or not granted then return Enum.ProductPurchaseDecision.NotProcessedYet end
		if store then
			local okSet = pcall(function() store:SetAsync(key, true) end)
			if not okSet then return Enum.ProductPurchaseDecision.NotProcessedYet end
		end
		print("[ReceiptService] Compra entregue: " .. key)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	print("[ReceiptService] Pronto")
end

return ReceiptService

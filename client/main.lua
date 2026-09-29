local ped = nil

local lastDebtNotice

local function notifyUnpaidBonds()
    local now = GetGameTimer()
    if lastDebtNotice and now - lastDebtNotice < 10000 then
        return
    end
    lastDebtNotice = now

    ESX.TriggerServerCallback("DE_bailbonds:getBonds", function(bonds)
        local count, total = 0, 0
        for _, bond in ipairs(bonds or {}) do
            if tonumber(bond.paid) ~= 1 then
                count = count + 1
                total = total + (tonumber(bond.price) or 0)
            end
        end

        if count > 0 then
            lib.notify({
                type = "warning",
                title = "Unpaid bond",
                description = ("You have %d unpaid bond(s), totaling $%d. Visit the bail bonds office or use /bondstatus."):format(count, total),
                duration = 10000,
            })
        end
    end)
end

RegisterNetEvent('esx:playerLoaded', function()
    Wait(5000)
    notifyUnpaidBonds()
end)

AddEventHandler('playerSpawned', function()
    Wait(5000)
    notifyUnpaidBonds()
end)

CreateThread(function()
    Wait(10000)
    notifyUnpaidBonds()

    while true do
        Wait(math.max(tonumber(Config.ReminderInterval) or 300000, 1000))
        notifyUnpaidBonds()
    end
end)

CreateThread(function()
	while true do
		Wait(500)

        local playerCoords = GetEntityCoords(PlayerPedId())
        local distance = #(playerCoords - Config.PedCoords.xyz)

        if distance < 6.0 and ped == nil then
            local spawnedPed = NearPed(Config.Ped, Config.PedCoords)
            ped = spawnedPed
        end

        if distance >= 6.0 and ped ~= nil then
            for i = 255, 0, -51 do
                Wait(50)
                SetEntityAlpha(ped, i, false)
            end
            DeletePed(ped)
            ped = nil
        end
	end
end)

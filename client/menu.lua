local menuOpen = false

local function loadBonds()
    ESX.TriggerServerCallback('DE_bailbonds:getBonds', function(bonds)
        SendNUIMessage({
            action = 'setBonds',
            bonds = bonds or {},
            payAccount = Config.PayAccount,
        })
    end)
end

local function closeMenu()
    if not menuOpen then
        return
    end

    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('DE_bailbonds:openMenu', function()
    if menuOpen then
        return
    end

    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    loadBonds()
end)

RegisterNUICallback('close', function(_, callback)
    closeMenu()
    callback({ ok = true })
end)

RegisterNUICallback('refresh', function(_, callback)
    loadBonds()
    callback({ ok = true })
end)

RegisterNUICallback('payBond', function(data, callback)
    local bondId = tonumber(data and data.id)
    if not menuOpen or not bondId or bondId < 1 or bondId % 1 ~= 0 then
        callback({ ok = false })
        return
    end

    TriggerServerEvent('DE_bailbonds:payBond', bondId)
    callback({ ok = true })
end)

RegisterNetEvent('DE_bailbonds:paymentResult', function(result)
    if not menuOpen then
        return
    end

    SendNUIMessage({ action = 'paymentResult', result = result })
    if result == 'success' then
        loadBonds()
    end
end)

local function displayBondStatus()
    ESX.TriggerServerCallback('DE_bailbonds:getBonds', function(bonds)
        local count, total = 0, 0
        for _, bond in ipairs(bonds or {}) do
            if tonumber(bond.paid) ~= 1 then
                count = count + 1
                total = total + (tonumber(bond.price) or 0)
            end
        end

        lib.notify({
            type = count > 0 and 'warning' or 'inform',
            title = 'Bond status',
            description = count > 0
                and ('You have %d unpaid bond(s), totaling $%d.'):format(count, total)
                or 'You have no unpaid bonds.',
        })
    end)
end

RegisterCommand('bondstatus', displayBondStatus, false)

CreateThread(function()
    while true do
        if menuOpen and IsControlJustReleased(0, 322) then
            closeMenu()
        end
        Wait(menuOpen and 0 or 500)
    end
end)

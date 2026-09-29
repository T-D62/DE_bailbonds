lib.registerMenu({
    id = 'bailbonds_menu',
    title = 'Bail Bonds',
    position = 'top-right',
    options = {
        {label = "Paid bonds", description = "View Paid Bonds"},
        {label = "Unpaid bonds", description = "View Unpaid Bonds"},
        {label = "Bond status", description = "Check your current bond balance"},
    },
}, function(selected, scrollIndex, args)
    if selected == 1 then
        TriggerEvent("DE_bailbonds:showBonds", true)
    elseif selected == 2 then
        TriggerEvent("DE_bailbonds:showBonds", false)
    elseif selected == 3 then
        TriggerEvent("DE_bailbonds:showBondStatus")
    end
end)

local function displayBondStatus()
    ESX.TriggerServerCallback("DE_bailbonds:getBonds", function(data)
        local count, total = 0, 0
        for _, bond in ipairs(data or {}) do
            if tonumber(bond.paid) ~= 1 then
                count = count + 1
                total = total + (tonumber(bond.price) or 0)
            end
        end

        lib.notify({
            type = count > 0 and "warning" or "inform",
            title = "Bond status",
            description = count > 0
                and ("You have %d unpaid bond(s), totaling $%d."):format(count, total)
                or "You have no unpaid bonds.",
        })
    end)
end

RegisterNetEvent("DE_bailbonds:showBondStatus", displayBondStatus)

RegisterCommand("bondstatus", displayBondStatus, false)


RegisterNetEvent("DE_bailbonds:showBonds")
AddEventHandler("DE_bailbonds:showBonds", function(paid)
    local Bonds = {}

    if paid then
        ESX.TriggerServerCallback("DE_bailbonds:getBonds", function(data)
            for k, v in pairs(data) do
                if tonumber(v.paid) == 1 then
                    table.insert(Bonds, {
                        label = v.name,
                        description = "Price: $" .. v.price
                    })
                end
            end

            if #Bonds > 0 then
                lib.registerMenu({
                    id = 'paid_menu',
                    title = 'Paid Bonds',
                    position = 'top-right',
                    options = Bonds,
                    onClose = function(keyPressed)
                        lib.showMenu('bailbonds_menu')
                    end,
                }, function(selected, scrollIndex, args)
                    lib.showMenu('bailbonds_menu')
                end)
                lib.showMenu('paid_menu')
            else
                lib.notify({type = "error", title = "Bond", description = "No paid bond at this time."})
            end
        end)
    else
        ESX.TriggerServerCallback("DE_bailbonds:getBonds", function(data)
            for k, v in pairs(data) do
                if tonumber(v.paid) ~= 1 then
                    table.insert(Bonds, {
                        label = v.name,
                        description = "Price: $" .. v.price,
                        args = {
                            id = v.id,
                            price = v.price,
                        },
                    })
                end
            end

            if #Bonds > 0 then
                lib.registerMenu({
                    id = 'unpaid_menu',
                    title = 'Unpaid Bonds',
                    position = 'top-right',
                    options = Bonds,
                    onClose = function(keyPressed)
                        lib.showMenu('bailbonds_menu')
                    end,
                }, function(selected, scrollIndex, args)
                    local confirmation = lib.alertDialog({
                        header = 'Confirm bond payment',
                        content = ('Pay $%s from your %s account?'):format(args and args.price or 0, Config.PayAccount),
                        centered = true,
                        cancel = true,
                    })

                    if confirmation == 'confirm' and args and args.id then
                        TriggerServerEvent('DE_bailbonds:payBond', args.id)
                    end
                    lib.showMenu('bailbonds_menu')
                end)
                lib.showMenu('unpaid_menu')
            else
                lib.notify({type = "error", title = "Bond", description = "No unpaid bond at this time."})
            end
        end)
    end
end)
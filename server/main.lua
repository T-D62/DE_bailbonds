local commandCooldowns = {}
local paymentsInProgress = {}

local function notify(source, kind, description)
    TriggerClientEvent('ox_lib:notify', source, {
        type = kind,
        title = 'Bond',
        icon = 'fas fa-handcuffs',
        description = description,
    })
end

local function logAction(action, officer, target, details)
    print(('[DE_bailbonds] %s | officer=%s | target=%s | %s'):format(
        action,
        officer or 'unknown',
        target or 'unknown',
        details or ''
    ))
end

local function canUsePoliceCommand(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not xPlayer.job then
        notify(source, 'error', 'This command can only be used by an in-game police officer.')
        return nil
    end

    for _, jobName in ipairs(Config.PoliceJobs or {}) do
        if xPlayer.job.name == jobName then
            return xPlayer
        end
    end

    notify(source, 'error', 'You are not authorized to use this command.')
    return nil
end

local function consumeCommandCooldown(source)
    local now = os.time()
    local cooldown = math.max(0, tonumber(Config.CommandCooldown) or 0)
    local availableAt = commandCooldowns[source] or 0

    if now < availableAt then
        notify(source, 'error', ('Please wait %d second(s) before using another bond command.'):format(availableAt - now))
        return false
    end

    commandCooldowns[source] = now + cooldown
    return true
end

local function getTarget(source, targetId)
    local id = tonumber(targetId)
    if not id or id < 1 or id % 1 ~= 0 then
        notify(source, 'error', 'Provide a valid player ID.')
        return nil
    end

    local target = ESX.GetPlayerFromId(id)
    if not target then
        notify(source, 'error', 'Player not online.')
        return nil
    end

    return target
end

local function ownerWhere(identifier, name)
    return '(identifier = ? OR (identifier IS NULL AND name = ?))', { identifier, name }
end

local function getPlayerBonds(xPlayer)
    local where, parameters = ownerWhere(xPlayer.identifier, xPlayer.getName())
    return MySQL.query.await(
        ('SELECT `id`, `name`, `price`, `paid`, `created_at`, `paid_at` FROM `user_bailbonds` WHERE %s ORDER BY `created_at` DESC'):format(where),
        parameters
    ) or {}
end

local function getAccountBalance(xPlayer)
    if Config.PayAccount == 'money' then
        return xPlayer.getMoney()
    end

    local account = xPlayer.getAccount(Config.PayAccount)
    return account and account.money or 0
end

local function removeAccountMoney(xPlayer, amount)
    if Config.PayAccount == 'money' then
        xPlayer.removeMoney(amount)
    else
        xPlayer.removeAccountMoney(Config.PayAccount, amount)
    end
end

local function getOwnerCondition(xPlayer)
    return '( `identifier` = ? OR (`identifier` IS NULL AND `name` = ?) )', {
        xPlayer.identifier,
        xPlayer.getName(),
    }
end

local function getCommandTarget(source, args)
    if not consumeCommandCooldown(source) then
        return nil, nil
    end

    local officer = canUsePoliceCommand(source)
    if not officer then
        return nil, nil
    end

    local target = getTarget(source, args.target)
    if not target then
        return nil, nil
    end

    return officer, target
end

lib.addCommand({ 'setbail', 'setbond' }, {
    help = 'Set a player’s bond',
    params = {
        { name = 'target', type = 'playerId', help = 'Target player ID' },
        { name = 'price', type = 'number', help = 'Bond amount' },
    },
}, function(source, args)
    local officer, target = getCommandTarget(source, args)
    if not officer then
        return
    end

    local amount = tonumber(args.price)
    local minimum = math.max(1, math.floor(tonumber(Config.MinimumBond) or 1))
    local maximum = math.floor(tonumber(Config.MaximumBond) or 1000000)
    if maximum < minimum then
        notify(source, 'error', 'Bond amount limits are misconfigured. Please contact an administrator.')
        return
    end
    if not amount or amount % 1 ~= 0 or amount < minimum or amount > maximum then
        notify(source, 'error', ('Bond amount must be a whole number between $%d and $%d.'):format(minimum, maximum))
        return
    end

    local ok, bondId = pcall(function()
        return MySQL.insert.await(
            'INSERT INTO `user_bailbonds` (`identifier`, `name`, `price`, `paid`, `officer_id`) VALUES (?, ?, ?, 0, ?)',
            { target.identifier, target.getName(), amount, officer.identifier }
        )
    end)

    if not ok or not bondId then
        notify(source, 'error', 'The bond could not be saved. Please try again.')
        logAction('set_failed', officer.identifier, target.identifier, ('amount=%s error=%s'):format(amount, bondId or 'database error'))
        return
    end

    notify(source, 'success', ('Set %s’s bond to $%d.'):format(target.getName(), amount))
    notify(target.source, 'inform', ('Your bond has been set to $%d.'):format(amount))
    logAction('set', officer.identifier, target.identifier, ('bond_id=%s amount=%d'):format(bondId, amount))
end)

lib.addCommand('getbond', {
    help = 'Check a player’s current bond status',
    params = {
        { name = 'target', type = 'playerId', help = 'Target player ID' },
    },
}, function(source, args)
    local officer, target = getCommandTarget(source, args)
    if not officer then
        return
    end

    local ok, bonds = pcall(function()
        return getPlayerBonds(target)
    end)
    if not ok then
        notify(source, 'error', 'Could not retrieve the player’s bond status.')
        logAction('status_failed', officer.identifier, target.identifier, tostring(bonds))
        return
    end

    local unpaidCount, unpaidTotal = 0, 0
    for _, bond in ipairs(bonds) do
        if tonumber(bond.paid) ~= 1 then
            unpaidCount = unpaidCount + 1
            unpaidTotal = unpaidTotal + (tonumber(bond.price) or 0)
        end
    end

    notify(source, 'inform', ('%s has %d unpaid bond(s), totaling $%d.'):format(target.getName(), unpaidCount, unpaidTotal))
    logAction('status_checked', officer.identifier, target.identifier, ('unpaid_count=%d total=%d'):format(unpaidCount, unpaidTotal))
end)

lib.addCommand('removebond', {
    help = 'Remove a player’s unpaid bonds',
    params = {
        { name = 'target', type = 'playerId', help = 'Target player ID' },
    },
}, function(source, args)
    local officer, target = getCommandTarget(source, args)
    if not officer then
        return
    end

    local ownerCondition, parameters = getOwnerCondition(target)
    local ok, removed = pcall(function()
        return MySQL.update.await(
            ('DELETE FROM `user_bailbonds` WHERE %s AND `paid` = 0'):format(ownerCondition),
            parameters
        )
    end)

    if not ok then
        notify(source, 'error', 'Could not remove the player’s unpaid bonds.')
        logAction('remove_failed', officer.identifier, target.identifier, tostring(removed))
        return
    end

    removed = tonumber(removed) or 0
    notify(source, 'success', ('Removed %d unpaid bond(s) for %s.'):format(removed, target.getName()))
    notify(target.source, 'inform', 'Your unpaid bonds have been cleared by an officer.')
    logAction('removed', officer.identifier, target.identifier, ('count=%d'):format(removed))
end)

ESX.RegisterServerCallback('DE_bailbonds:getBonds', function(source, callback)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        callback({})
        return
    end

    local ok, bonds = pcall(function()
        return getPlayerBonds(xPlayer)
    end)
    if not ok then
        print(('[DE_bailbonds] Failed to load bonds for %s: %s'):format(xPlayer.identifier, tostring(bonds)))
        callback({})
        return
    end

    callback(bonds)
end)

RegisterNetEvent('DE_bailbonds:payBond', function(bondId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local id = tonumber(bondId)
    if not xPlayer or not id or id < 1 or id % 1 ~= 0 then
        notify(source, 'error', 'Invalid bond selection.')
        return
    end

    if paymentsInProgress[id] then
        notify(source, 'error', 'This bond payment is already being processed.')
        return
    end
    paymentsInProgress[id] = true

    local ok, result = pcall(function()
        local ownerCondition, parameters = getOwnerCondition(xPlayer)
        table.insert(parameters, 1, id)
        local bond = MySQL.single.await(
            ('SELECT `id`, `name`, `price`, `paid` FROM `user_bailbonds` WHERE `id` = ? AND %s LIMIT 1'):format(ownerCondition),
            parameters
        )

        if not bond or tonumber(bond.paid) == 1 then
            return 'unavailable'
        end

        local price = tonumber(bond.price)
        if not price or price < 0 or getAccountBalance(xPlayer) < price then
            return 'insufficient'
        end

        local updateParameters = { id }
        for _, parameter in ipairs(parameters) do
            table.insert(updateParameters, parameter)
        end
        local updated = MySQL.update.await(
            ('UPDATE `user_bailbonds` SET `paid` = 1, `paid_at` = CURRENT_TIMESTAMP WHERE `id` = ? AND %s AND `paid` = 0'):format(ownerCondition),
            updateParameters
        )
        if tonumber(updated) ~= 1 then
            return 'unavailable'
        end

        removeAccountMoney(xPlayer, price)
        TriggerEvent('esx_addonaccount:getSharedAccount', Config.SocietyAccount, function(account)
            if account then
                account.addMoney(price)
            else
                print(('[DE_bailbonds] Society account %s is unavailable for bond %s'):format(Config.SocietyAccount, id))
            end
        end)
        logAction('paid', xPlayer.identifier, xPlayer.identifier, ('bond_id=%s amount=%d'):format(id, price))
        return ('paid:%s:%d'):format(bond.name, price)
    end)

    paymentsInProgress[id] = nil
    if not ok then
        notify(source, 'error', 'The payment could not be processed. Please contact an administrator.')
        print(('[DE_bailbonds] Payment failed for bond %s: %s'):format(id, tostring(result)))
    elseif result == 'unavailable' then
        notify(source, 'error', 'This bond is no longer available to pay.')
    elseif result == 'insufficient' then
        notify(source, 'error', 'You do not have enough money to pay this bond.')
    else
        local name, price = result:match('^paid:(.*):(%d+)$')
        notify(source, 'success', ('You paid %s’s bond of $%s.'):format(name or 'the player', price or '0'))
    end
end)

AddEventHandler('playerDropped', function()
    commandCooldowns[source] = nil
end)

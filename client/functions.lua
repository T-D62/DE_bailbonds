NearPed = function(model, coords)
    RequestModel(model)
	while not HasModelLoaded(model) do
		Wait(50)
	end

	spawnedPed = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)

	SetEntityAlpha(spawnedPed, 0, false)
	FreezeEntityPosition(spawnedPed, true)
	SetEntityInvincible(spawnedPed, true)
	SetBlockingOfNonTemporaryEvents(spawnedPed, true)

    for i = 0, 255, 51 do
        Wait(50)
        SetEntityAlpha(spawnedPed, i, false)
    end

    exports.ox_target:addLocalEntity(spawnedPed, {
        {
            label = 'View Bonds',
            icon = 'fas fa-handcuffs',
            onSelect = function(data)
                TriggerEvent('DE_bailbonds:openMenu')
            end,
        },
    })

	return spawnedPed
end
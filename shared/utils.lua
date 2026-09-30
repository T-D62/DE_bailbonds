BailBonds = {}

function BailBonds.CalculateAccruedAmount(principal, rate, periods)
    principal = tonumber(principal)
    rate = tonumber(rate)
    periods = tonumber(periods)

    if not principal or not rate or not periods or principal < 0 or rate < 0 or periods < 0 then
        return nil
    end

    return math.floor((principal * ((1 + rate) ^ periods)) + 0.5)
end

function BailBonds.GetAccrualPeriods(createdAt, periodDays, now)
    periodDays = tonumber(periodDays)
    if type(createdAt) ~= 'number' or not periodDays or periodDays <= 0 then
        return 0
    end

    return math.max(0, math.floor(((now or os.time()) - createdAt) / (periodDays * 24 * 60 * 60)))
end

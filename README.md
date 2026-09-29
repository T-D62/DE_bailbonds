# DE_bailbonds

A bail bond resource for FiveM servers running ESX, ox_lib, oxmysql, ox_target, esx_addonaccount, and okokNotify. It provides a nearby bail-bonds NPC, officer bond management, player bond status, and server-validated payments to the configured police society account.

## Requirements

- `es_extended`
- `ox_lib`
- `oxmysql`
- `ox_target`
- `esx_addonaccount` with the configured society account
- `okokNotify`
- The `ReaperV4` resource referenced by this resource's `fxmanifest.lua`

## Installation

1. Place `DE_bailbonds` in your server resources.
2. For a new installation, import [`bailbonds.sql`](bailbonds.sql) into the server database.
3. For an existing installation, apply the one-time migration below before restarting the resource. Existing bonds remain in the table; old rows keep a `NULL` identifier and are matched by character name until paid or removed.
4. Review the settings in `config.lua`, especially `PoliceJobs`, `PayAccount`, and `SocietyAccount` (defaults to `society_police`).
5. Ensure the dependencies start before this resource, then add `ensure DE_bailbonds` to `server.cfg`.

### Existing database migration

Run this once against the existing `user_bailbonds` table:

```sql
ALTER TABLE `user_bailbonds`
    ADD COLUMN `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST,
    ADD COLUMN `identifier` VARCHAR(100) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci' AFTER `id`,
    ADD COLUMN `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN `paid_at` TIMESTAMP NULL DEFAULT NULL,
    ADD COLUMN `officer_id` VARCHAR(100) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
    ADD INDEX `idx_user_bailbonds_identifier_paid` (`identifier`, `paid`),
    ADD INDEX `idx_user_bailbonds_name_paid` (`name`, `paid`),
    ADD INDEX `idx_user_bailbonds_officer_id` (`officer_id`),
    ADD INDEX `idx_user_bailbonds_created_at` (`created_at`);
```

Existing paid rows retain a `NULL` `paid_at`, because their payment time is unknown.

## Configuration

| Setting | Purpose |
| --- | --- |
| `Config.PayAccount` | Account charged for payment: `bank` or `money`. |
| `Config.SocietyAccount` | Shared society account credited after payment. |
| `Config.MinimumBond` / `Config.MaximumBond` | Inclusive whole-number limits for newly set bonds. |
| `Config.CommandCooldown` | Minimum seconds between officer bond commands per player. |
| `Config.ReminderInterval` | Client reminder interval in milliseconds (default: five minutes). |
| `Config.Interest.Enabled` | Interest feature switch for integrations using the shared accrual helpers; disabled by default. |
| `Config.Interest.Rate` | Interest rate per accrual period, expressed as a decimal (for example, `0.05` for 5%). |
| `Config.Interest.PeriodDays` | Number of days in an accrual period. |
| `Config.Ped` / `Config.PedCoords` | NPC model and location. |
| `Config.PoliceJobs` | ESX job names allowed to use officer commands. |

The included interest helpers are available as `BailBonds.CalculateAccruedAmount(principal, rate, periods)` and `BailBonds.GetAccrualPeriods(createdAtUnix, periodDays, nowUnix)`. Interest is not automatically added to a bond or payment; the default behavior preserves the entered bond amount.

## Commands

| Command | Access | Description |
| --- | --- | --- |
| `/setbail <playerId> <amount>` | Configured police jobs | Create a bond for an online player. `/setbond` is an alias. |
| `/getbond <playerId>` | Configured police jobs | Show the target's unpaid bond count and total. |
| `/removebond <playerId>` | Configured police jobs | Delete the target's unpaid bonds; paid history is retained. |
| `/bondstatus` | Any player | Show your own unpaid bond count and total. |

Officers receive confirmation or validation errors in-game. Set, status-check, removal, payment, and database failure events are also written to the server console with officer/player identifiers.

## Player payments

Players can interact with the bail-bonds NPC to open the NUI dashboard, which lists unpaid bonds across the server so a player can pay a bond for someone else, shows the current player's paid history, and confirms payments. Notifications use `okokNotify`. Unpaid debts are notified after spawn and reminded at the configured interval; `/bondstatus` remains available. The server looks up the selected unpaid bond by its database ID, charges the payer, and credits the configured shared police society account; if that account is unavailable, the payment is not taken. Client-supplied prices and names are never used to charge money.

## Database tracking

Each row records its player identifier, bond amount, paid state, creation/payment timestamps, and the officer identifier that set it. Indexes cover player/status lookups, legacy name/status lookups, officer identifiers, and creation time.

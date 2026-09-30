CREATE TABLE IF NOT EXISTS `user_bailbonds` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(100) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
    `name` VARCHAR(255) NOT NULL COLLATE 'utf8mb4_unicode_ci',
    `price` INT UNSIGNED NOT NULL,
    `paid` TINYINT(1) NOT NULL DEFAULT '0',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `paid_at` TIMESTAMP NULL DEFAULT NULL,
    `officer_id` VARCHAR(100) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
    PRIMARY KEY (`id`),
    INDEX `idx_user_bailbonds_identifier_paid` (`identifier`, `paid`),
    INDEX `idx_user_bailbonds_name_paid` (`name`, `paid`),
    INDEX `idx_user_bailbonds_officer_id` (`officer_id`),
    INDEX `idx_user_bailbonds_created_at` (`created_at`)
)
COLLATE='utf8mb4_unicode_ci'
ENGINE=InnoDB;

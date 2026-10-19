USE spotify_db;

-- 1. DAU — количество уникальных пользователей в день
-- ============================================================

SELECT
    payment_date AS activity_day,
    COUNT(DISTINCT user_id) AS DAU
FROM payments
GROUP BY payment_date
ORDER BY payment_date;


-- 2. WAU — количество уникальных пользователей в неделю
-- ============================================================

SELECT
    MIN(payment_date) AS week_start,
    COUNT(DISTINCT user_id) AS WAU
FROM payments
GROUP BY YEARWEEK(payment_date, 1)
ORDER BY week_start;


-- 3. MAU — количество уникальных пользователей в месяц
-- ============================================================

SELECT
    DATE_FORMAT(payment_date, '%Y-%m') AS month,
    COUNT(DISTINCT user_id) AS MAU
FROM payments
GROUP BY DATE_FORMAT(payment_date, '%Y-%m')
ORDER BY month;


-- 4. RETENTION RATE — процент удержанных пользователей
--
-- Пользователь считается удержанным, если он совершил платеж
-- в предыдущем месяце и снова совершил платеж в следующем.
-- ============================================================

WITH monthly_users AS (
    SELECT DISTINCT
        user_id,
        DATE_FORMAT(payment_date, '%Y-%m') AS month
    FROM payments
),

retention AS (
    SELECT
        prev.month AS previous_month,
        COUNT(DISTINCT prev.user_id) AS users_previous_month,
        COUNT(DISTINCT curr.user_id) AS retained_users
    FROM monthly_users prev
    LEFT JOIN monthly_users curr
        ON prev.user_id = curr.user_id
        AND curr.month = DATE_FORMAT(
            DATE_ADD(
                STR_TO_DATE(CONCAT(prev.month, '-01'), '%Y-%m-%d'),
                INTERVAL 1 MONTH
            ),
            '%Y-%m'
        )
    GROUP BY prev.month
)

SELECT
    previous_month,
    users_previous_month,
    retained_users,
    ROUND(
        retained_users * 100.0 / NULLIF(users_previous_month, 0),
        2
    ) AS retention_rate
FROM retention
WHERE previous_month < (
    SELECT MAX(month)
    FROM monthly_users
)
ORDER BY previous_month


-- 5. CHURN RATE
-- Пользователи, которые не продлили подписку
-- =========================================

WITH user_subscriptions AS (
    SELECT
        user_id,
        COUNT(*) AS subscription_count
    FROM subscriptions
    GROUP BY user_id
)

SELECT
    COUNT(*) AS total_subscribers,

    SUM(
        CASE
            WHEN subscription_count = 1 THEN 1
            ELSE 0
        END
    ) AS churned_users,

    ROUND(
        SUM(
            CASE
                WHEN subscription_count = 1 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS churn_rate
FROM user_subscriptions;


-- =========================================
-- ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА
-- Количество подписок каждого пользователя
-- =========================================

SELECT
    user_id,
    COUNT(*) AS subscription_count,
    CASE
        WHEN COUNT(*) > 1 THEN 'Retained'
        ELSE 'Churned'
    END AS user_status
FROM subscriptions
GROUP BY user_id
ORDER BY user_id;

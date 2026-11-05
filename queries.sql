-- =====================================================================
-- Где интернет-магазин теряет клиентов и деньги — анализ на SQL (SQLite)
-- Данные: 2 000 пользователей, 3 751 заказ, 12 903 события, 2025 год
-- =====================================================================


-- 1. Воронка: сколько событий и людей на каждом этапе
SELECT
    CASE
        WHEN event_type IN ('visit', 'view_product')     THEN '1. Смотрит'
        WHEN event_type IN ('add_to_cart', 'checkout')   THEN '2. Собирается купить'
        WHEN event_type = 'purchase'                     THEN '3. Купил'
    END                         AS этап,
    COUNT(*)                    AS событий,
    COUNT(DISTINCT user_id)     AS людей
FROM events
GROUP BY этап
ORDER BY этап;


-- 2. Каналы привлечения: какая доля зарегистрированных сделала хотя бы один доставленный заказ
--    LEFT JOIN + условие в ON: люди без покупок остаются в знаменателе
SELECT
    u.source                                    AS канал,
    COUNT(DISTINCT u.user_id)                   AS зарегистрировались,
    COUNT(DISTINCT o.user_id)                   AS купили,
    ROUND(COUNT(DISTINCT o.user_id) * 100.0 / COUNT(DISTINCT u.user_id), 1) AS конверсия_pct
FROM users u
LEFT JOIN orders o
       ON o.user_id = u.user_id
      AND o.status = 'delivered'
GROUP BY u.source
ORDER BY конверсия_pct DESC;


-- 3. Доля отмен по каналам (сравниваем каналы разного размера через долю)
SELECT
    u.source                                                        AS канал,
    COUNT(*)                                                        AS заказов,
    SUM(CASE WHEN o.status = 'cancelled' THEN 1 ELSE 0 END)         AS отменено,
    ROUND(SUM(CASE WHEN o.status = 'cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS доля_отмен_pct
FROM orders o
JOIN users u ON o.user_id = u.user_id
GROUP BY u.source
ORDER BY доля_отмен_pct DESC;


-- 4. Топ-5 товаров по доле возвратов
SELECT
    p.name                                                          AS товар,
    p.category                                                      AS категория,
    COUNT(DISTINCT o.order_id)                                      AS заказов,
    SUM(CASE WHEN o.status = 'returned' THEN 1 ELSE 0 END)          AS возвратов,
    ROUND(SUM(CASE WHEN o.status = 'returned' THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT o.order_id), 1) AS доля_возвратов_pct
FROM products p
JOIN order_items oi ON oi.product_id = p.product_id
JOIN orders o       ON o.order_id    = oi.order_id
GROUP BY p.name, p.category
ORDER BY доля_возвратов_pct DESC
LIMIT 5;


-- 5. Средний чек доставленных заказов по промокодам
SELECT
    COALESCE(o.promo_code, 'без промокода')                         AS промокод,
    COUNT(DISTINCT o.order_id)                                      AS заказов,
    ROUND(SUM(oi.quantity * oi.price))                              AS выручка,
    ROUND(SUM(oi.quantity * oi.price) / COUNT(DISTINCT o.order_id)) AS средний_чек
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status = 'delivered'
GROUP BY o.promo_code
ORDER BY средний_чек DESC;


-- 6. Конверсия в покупку по поколениям
SELECT
    CASE
        WHEN u.birth_year < 1980 THEN '1. до 1980'
        WHEN u.birth_year < 1990 THEN '2. 1980-е'
        WHEN u.birth_year < 2000 THEN '3. 1990-е'
        ELSE                          '4. 2000 и позже'
    END                                                             AS поколение,
    COUNT(DISTINCT u.user_id)                                       AS людей,
    COUNT(DISTINCT o.user_id)                                       AS купили,
    ROUND(COUNT(DISTINCT o.user_id) * 100.0 / COUNT(DISTINCT u.user_id), 1) AS конверсия_pct,
    COUNT(o.order_id)                                               AS доставленных_заказов
FROM users u
LEFT JOIN orders o
       ON o.user_id = u.user_id
      AND o.status = 'delivered'
GROUP BY поколение
ORDER BY конверсия_pct DESC;

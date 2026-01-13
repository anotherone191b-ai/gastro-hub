

WITH manager_counts AS (
    SELECT 
        r.name as restaurant_name,
        COUNT(DISTINCT w.manager_uuid) as unique_managers_count
    FROM cafe.restaurant_manager_work_dates w
    JOIN cafe.restaurants r ON w.restaurant_uuid = r.restaurant_uuid
    GROUP BY r.restaurant_uuid, r.name
    HAVING COUNT(DISTINCT w.manager_uuid) > 1
),
ranked AS (
    SELECT 
        restaurant_name,
        unique_managers_count,
        ROW_NUMBER() OVER (ORDER BY unique_managers_count DESC, restaurant_name) as rank_num
    FROM manager_counts
)
SELECT 
    restaurant_name as "Название заведения",
    (unique_managers_count - 1) as "Сколько раз менялся менеджер"  -- Вычитаем 1, так как первый менеджер не считается сменой
FROM ranked
WHERE rank_num <= 3
ORDER BY "Сколько раз менялся менеджер" DESC;
-- Создание представления для топ-3 заведений по типу
CREATE OR REPLACE VIEW cafe.top_restaurants_by_type AS
WITH restaurant_stats AS (
    SELECT 
        r.restaurant_uuid,
        r.name as restaurant_name,
        r.type as restaurant_type,
        ROUND(AVG(s.avg_check)::numeric, 2) as avg_check
    FROM cafe.restaurants r
    INNER JOIN cafe.sales s ON r.restaurant_uuid = s.restaurant_uuid
    GROUP BY r.restaurant_uuid, r.name, r.type
),
ranked_restaurants AS (
    SELECT 
        restaurant_name,
        restaurant_type,
        avg_check,
        ROW_NUMBER() OVER (
            PARTITION BY restaurant_type 
            ORDER BY avg_check DESC
        ) as rank_in_type
    FROM restaurant_stats
)
SELECT 
    restaurant_name as "Название заведения",
    restaurant_type as "Тип заведения",
    avg_check as "Средний чек"
FROM ranked_restaurants
WHERE rank_in_type <= 3
ORDER BY 
    CASE restaurant_type 
        WHEN 'coffee_shop' THEN 1
        WHEN 'restaurant' THEN 2
        WHEN 'pizzeria' THEN 3
        WHEN 'bar' THEN 4
        ELSE 5
    END,
    rank_in_type;

-- Комментарий к представлению
COMMENT ON VIEW cafe.top_restaurants_by_type IS 'Топ-3 заведения каждого типа по среднему чеку за все даты';
-- Находим пиццерию с самым большим количеством пицц в меню
WITH pizzeria_pizzas AS (
    SELECT 
        r.name as restaurant_name,
        -- Извлекаем количество пицц из JSONB меню
        (
            SELECT COUNT(*) 
            FROM jsonb_each(r.menu->'Пицца')
        ) as pizza_count
    FROM cafe.restaurants r
    WHERE r.type = 'pizzeria'::cafe.restaurant_type
      AND r.menu IS NOT NULL
      AND r.menu->'Пицца' IS NOT NULL
),
ranked_pizzerias AS (
    SELECT 
        restaurant_name,
        pizza_count,
        DENSE_RANK() OVER (ORDER BY pizza_count DESC) as rank_position
    FROM pizzeria_pizzas
)
SELECT 
    restaurant_name as "Название заведения",
    pizza_count as "Количество пицц в меню"
FROM ranked_pizzerias
WHERE rank_position = 1
ORDER BY restaurant_name;
-- Находим самую дорогую пиццу для каждой пиццерии
WITH menu_cte AS (
    SELECT 
        r.name as restaurant_name,
        'Пицца' as dish_type,
        pizza.key as pizza_name,
        (pizza.value)::numeric as price
    FROM cafe.restaurants r,
    jsonb_each_text(r.menu->'Пицца') as pizza
    WHERE r.type = 'pizzeria'::cafe.restaurant_type
      AND r.menu->'Пицца' IS NOT NULL
),
menu_with_rank AS (
    SELECT 
        restaurant_name,
        dish_type,
        pizza_name,
        price,
        ROW_NUMBER() OVER (
            PARTITION BY restaurant_name 
            ORDER BY price DESC, pizza_name
        ) as price_rank
    FROM menu_cte
)
SELECT 
    restaurant_name as "Название заведения",
    dish_type as "Тип блюда",
    pizza_name as "Название пиццы",
    price::integer as "Цена"
FROM menu_with_rank
WHERE price_rank = 1
ORDER BY restaurant_name;
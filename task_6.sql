-- Начинаем транзакцию для безопасного обновления цен
BEGIN;

-- Блокируем строки, которые будем обновлять, для исключения конкурентных изменений
-- Используем FOR UPDATE для предотвращения изменений другими транзакциями
WITH cafes_to_update AS (
    SELECT r.restaurant_uuid
    FROM cafe.restaurants r
    WHERE r.type = 'coffee_shop'::cafe.restaurant_type
      AND r.menu->'Кофе'->'Капучино' IS NOT NULL
    FOR UPDATE
),
-- Вычисляем новые цены для капучино (увеличение на 20%)
updated_prices AS (
    SELECT 
        r.restaurant_uuid,
        r.name,
        r.menu,
        -- Обновляем только цену на капучино, остальное меню оставляем без изменений
        jsonb_set(
            r.menu,
            '{Кофе,Капучино}',
            to_jsonb(
                ROUND((COALESCE((r.menu->'Кофе'->>'Капучино')::numeric, 0) * 1.2)::numeric, 0)
            )
        ) as new_menu
    FROM cafe.restaurants r
    WHERE r.type = 'coffee_shop'::cafe.restaurant_type
      AND r.menu->'Кофе'->'Капучино' IS NOT NULL
)
-- Обновляем меню в заведениях
UPDATE cafe.restaurants r
SET menu = up.new_menu
FROM updated_prices up
WHERE r.restaurant_uuid = up.restaurant_uuid;

-- Коммитим изменения
COMMIT;
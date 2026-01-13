BEGIN;

-- 1. Сначала очищаем таблицы (опционально, если нужно перезаполнить)
-- TRUNCATE cafe.sales, cafe.restaurant_manager_work_dates, cafe.managers, cafe.restaurants RESTART IDENTITY;

-- 2. Наполнение таблицы cafe.restaurants из raw_data.menu
-- Определяем тип заведения на основе данных из raw_data.sales и названия
WITH restaurant_types AS (
    SELECT 
        DISTINCT m.cafe_name,
        CASE 
            -- Определяем тип заведения по имени
            WHEN m.cafe_name LIKE '%Бар%' OR m.cafe_name IN (
                'Spirits & Spices', 'Вино и Вода', 'Hops Heaven', 'Пивной Парад', 
                'Malt Mansion', 'Шоты Шерифа', 'Craft & Draft', 'Коктейль Королей',
                'Boozy Boulevard', 'Бар Барон', 'Liquor Library', 'Бокалы Богатства',
                'Gin & Juice', 'Таверна Талантов', 'Rum Runner', 'Веселье в Виски',
                'Tequila Town', 'Барман Бей', 'Mixology Mastery'
            ) THEN 'bar'::cafe.restaurant_type
            
            WHEN m.cafe_name LIKE '%Коф%' OR m.cafe_name LIKE '%Капучино%' OR m.cafe_name LIKE '%Эспрессо%' 
                 OR m.cafe_name IN (
                    'Caffeine Castle', 'Brewed Awakening', 'Ванильная Визия', 'Mocha Magic',
                    'Кофе Коннект', 'Roast & Toast', 'Латте Люкс', 'Choco Charm', 'Бодрый Бариста',
                    'Cup o'' Joe', 'Магия Макиато', 'Bean Bliss', 'Рай Ристретто', 
                    'Grounds for Celebration', 'Кофейный Космос', 'Espresso Emporium',
                    'Бариста Битва', 'Coffee Carnival'
                 ) THEN 'coffee_shop'::cafe.restaurant_type
            
            WHEN m.cafe_name LIKE '%Пицц%' OR m.cafe_name LIKE '%Pizza%' OR m.cafe_name IN (
                'Dough & Cheese', 'Звезда Неаполя', 'Slice of Rome', 'Вкус Венеции',
                'Pizza Picasso', 'Тосканский Трактир', 'Sicilian Secret', 'Базилик и Орегано',
                'Brick Oven Bliss', 'Пицца Парадизо', 'Mozzarella Majesty', 'Королевство Кальцоне',
                'Provolone Palace', 'Место Маргариты', 'Pepperoni Passion', 'Салют Сицилии',
                'Gourmet Garlic', 'Пицца Приключение', 'Napoli Nights'
            ) THEN 'pizzeria'::cafe.restaurant_type
            
            ELSE 'restaurant'::cafe.restaurant_type
        END as restaurant_type
    FROM raw_data.menu m
)
INSERT INTO cafe.restaurants (name, type, menu)
SELECT 
    m.cafe_name,
    COALESCE(rt.restaurant_type, 'restaurant'::cafe.restaurant_type),
    m.menu
FROM raw_data.menu m
LEFT JOIN restaurant_types rt ON m.cafe_name = rt.cafe_name
ON CONFLICT (name) DO UPDATE SET
    type = EXCLUDED.type,
    menu = EXCLUDED.menu;

-- Проверка
SELECT 'Рестораны добавлено: ' || COUNT(*) FROM cafe.restaurants;

-- 3. Наполнение таблицы cafe.managers из raw_data.sales
INSERT INTO cafe.managers (name, phone)
SELECT DISTINCT
    TRIM(s.manager) as name,
    TRIM(s.manager_phone) as phone
FROM raw_data.sales s
WHERE s.manager IS NOT NULL 
  AND s.manager_phone IS NOT NULL
  AND TRIM(s.manager) != ''
  AND TRIM(s.manager_phone) != ''
ON CONFLICT (phone) DO UPDATE SET
    name = EXCLUDED.name;

-- Проверка
SELECT 'Менеджеры добавлено: ' || COUNT(*) FROM cafe.managers;

-- 4. Наполнение таблицы cafe.restaurant_manager_work_dates
INSERT INTO cafe.restaurant_manager_work_dates (
    restaurant_uuid, 
    manager_uuid, 
    work_start_date, 
    work_end_date
)
SELECT 
    r.restaurant_uuid,
    m.manager_uuid,
    MIN(s.report_date) AS work_start_date,
    MAX(s.report_date) AS work_end_date
FROM raw_data.sales s
INNER JOIN cafe.restaurants r ON s.cafe_name = r.name
INNER JOIN cafe.managers m ON TRIM(s.manager_phone) = m.phones[2] -- Используем старый телефон из массива
WHERE s.manager IS NOT NULL 
  AND s.manager_phone IS NOT NULL
GROUP BY r.restaurant_uuid, m.manager_uuid
ON CONFLICT (restaurant_uuid, manager_uuid) DO UPDATE SET
    work_start_date = LEAST(restaurant_manager_work_dates.work_start_date, EXCLUDED.work_start_date),
    work_end_date = GREATEST(
        COALESCE(restaurant_manager_work_dates.work_end_date, EXCLUDED.work_end_date), 
        EXCLUDED.work_end_date
    );

-- Альтернативный вариант, если phones массив еще не создан:
/*
INSERT INTO cafe.restaurant_manager_work_dates (
    restaurant_uuid, 
    manager_uuid, 
    work_start_date, 
    work_end_date
)
SELECT 
    r.restaurant_uuid,
    m.manager_uuid,
    MIN(s.report_date) AS work_start_date,
    MAX(s.report_date) AS work_end_date
FROM raw_data.sales s
INNER JOIN cafe.restaurants r ON s.cafe_name = r.name
INNER JOIN cafe.managers m ON TRIM(s.manager_phone) = (
    SELECT phone FROM cafe.managers m2 
    WHERE m2.manager_uuid = m.manager_uuid
    AND phones IS NULL -- Для старых записей
    LIMIT 1
)
WHERE s.manager IS NOT NULL 
  AND s.manager_phone IS NOT NULL
GROUP BY r.restaurant_uuid, m.manager_uuid
ON CONFLICT (restaurant_uuid, manager_uuid) DO NOTHING;
*/

-- Проверка
SELECT 'Периоды работы добавлено: ' || COUNT(*) FROM cafe.restaurant_manager_work_dates;

-- 5. Наполнение таблицы cafe.sales
INSERT INTO cafe.sales (sale_date, restaurant_uuid, avg_check)
SELECT 
    s.report_date,
    r.restaurant_uuid,
    s.avg_check
FROM raw_data.sales s
INNER JOIN cafe.restaurants r ON s.cafe_name = r.name
ON CONFLICT (sale_date, restaurant_uuid) DO UPDATE SET
    avg_check = EXCLUDED.avg_check;

-- Проверка
SELECT 'Продажи добавлено: ' || COUNT(*) FROM cafe.sales;

-- 6. Итоговая проверка целостности данных
SELECT 
    'Рестораны' as "Таблица",
    COUNT(*) as "Записей"
FROM cafe.restaurants

UNION ALL

SELECT 
    'Менеджеры',
    COUNT(*)
FROM cafe.managers

UNION ALL

SELECT 
    'Периоды работы',
    COUNT(*)
FROM cafe.restaurant_manager_work_dates

UNION ALL

SELECT 
    'Продажи',
    COUNT(*)
FROM cafe.sales

ORDER BY "Таблица";

-- Проверка соответствия с исходными данными
SELECT 
    'Исходные заведения' as "Источник",
    COUNT(DISTINCT cafe_name) as "Количество"
FROM raw_data.menu

UNION ALL

SELECT 
    'Загруженные заведения',
    COUNT(DISTINCT name)
FROM cafe.restaurants

UNION ALL

SELECT 
    'Исходные продажи',
    COUNT(*)
FROM raw_data.sales

UNION ALL

SELECT 
    'Загруженные продажи',
    COUNT(*)
FROM cafe.sales;

COMMIT;
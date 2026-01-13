-- Создание материализованного представления для анализа динамики среднего чека по годам
CREATE MATERIALIZED VIEW cafe.yearly_avg_check_dynamics AS
WITH yearly_stats AS (
    SELECT 
        EXTRACT(YEAR FROM s.sale_date) as year_num,
        s.restaurant_uuid,
        ROUND(AVG(s.avg_check)::numeric, 2) as avg_check_current_year
    FROM cafe.sales s
    WHERE EXTRACT(YEAR FROM s.sale_date) <> 2023  -- Исключаем 2023 год
    GROUP BY EXTRACT(YEAR FROM s.sale_date), s.restaurant_uuid
),
restaurant_info AS (
    SELECT 
        ys.year_num,
        ys.restaurant_uuid,
        ys.avg_check_current_year,
        r.name as restaurant_name,
        r.type as restaurant_type
    FROM yearly_stats ys
    JOIN cafe.restaurants r ON ys.restaurant_uuid = r.restaurant_uuid
),
with_prev_year AS (
    SELECT 
        year_num::integer as year,
        restaurant_name,
        restaurant_type,
        avg_check_current_year,
        LAG(avg_check_current_year) OVER (
            PARTITION BY restaurant_uuid 
            ORDER BY year_num
        ) as prev_year_check
    FROM restaurant_info
)
SELECT 
    year as "Год",
    restaurant_name as "Название заведения",
    restaurant_type as "Тип заведения",
    avg_check_current_year as "Средний чек в текущем году",
    prev_year_check as "Средний чек в предыдущем году",
    CASE 
        WHEN prev_year_check IS NOT NULL AND prev_year_check > 0
        THEN ROUND(((avg_check_current_year - prev_year_check) / prev_year_check * 100)::numeric, 2)
        ELSE NULL
    END as "Изменение среднего чека в %"
FROM with_prev_year
ORDER BY 
    restaurant_name,
    year;

-- Комментарий к материализованному представлению
COMMENT ON MATERIALIZED VIEW cafe.yearly_avg_check_dynamics IS 'Динамика среднего чека по годам для каждого заведения (без 2023 года)';

-- Создание индексов для быстрого поиска
CREATE INDEX idx_yearly_dynamics_restaurant ON cafe.yearly_avg_check_dynamics("Название заведения");
CREATE INDEX idx_yearly_dynamics_year ON cafe.yearly_avg_check_dynamics("Год");
CREATE INDEX idx_yearly_dynamics_type ON cafe.yearly_avg_check_dynamics("Тип заведения");
-- Начинаем транзакцию для безопасного обновления структуры таблицы
BEGIN;

-- Блокируем таблицу managers в режиме SHARE ROW EXCLUSIVE
-- Этот режим позволяет чтение, но запрещает изменения другим транзакциям
LOCK TABLE cafe.managers IN SHARE ROW EXCLUSIVE MODE;

-- 1. Добавляем новое поле для массива телефонов
ALTER TABLE cafe.managers 
ADD COLUMN IF NOT EXISTS phones VARCHAR(20)[];

-- 2. Вычисляем новый номер телефона для каждого менеджера по алфавиту
WITH numbered_managers AS (
    SELECT 
        manager_uuid,
        name,
        phone as old_phone,
        -- Нумерация менеджеров по алфавиту, начиная с 100
        100 + ROW_NUMBER() OVER (ORDER BY name) - 1 as manager_number
    FROM cafe.managers
    ORDER BY name
),
updated_phones AS (
    SELECT 
        manager_uuid,
        old_phone,
        -- Формируем новый номер: 8-800-2500-XXX
        CONCAT('8-800-2500-', LPAD(manager_number::text, 3, '0')) as new_phone,
        -- Создаем массив: [новый_номер, старый_номер]
        ARRAY[
            CONCAT('8-800-2500-', LPAD(manager_number::text, 3, '0')),
            old_phone
        ] as phones_array
    FROM numbered_managers
)
-- 3. Обновляем таблицу: заполняем массив телефонов
UPDATE cafe.managers m
SET phones = up.phones_array
FROM updated_phones up
WHERE m.manager_uuid = up.manager_uuid;

-- 4. Удаляем старое поле с телефоном
ALTER TABLE cafe.managers 
DROP COLUMN phone;

-- Фиксируем изменения
COMMIT;
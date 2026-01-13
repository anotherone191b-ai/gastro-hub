-- Создание схемы cafe
CREATE SCHEMA IF NOT EXISTS cafe;

-- Создание ENUM типа заведения в схеме cafe
CREATE TYPE cafe.restaurant_type AS ENUM (
    'coffee_shop',
    'restaurant', 
    'bar',
    'pizzeria'
);

-- Комментарий к ENUM типу
COMMENT ON TYPE cafe.restaurant_type IS 'Типы заведений: кофейня, ресторан, бар, пиццерия';





-- Таблица ресторанов в схеме cafe
CREATE TABLE cafe.restaurants (
    restaurant_uuid UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type cafe.restaurant_type NOT NULL,
    menu JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_restaurant_name UNIQUE (name)
);

-- Комментарии к таблице и колонкам
COMMENT ON TABLE cafe.restaurants IS 'Таблица заведений с их меню';
COMMENT ON COLUMN cafe.restaurants.restaurant_uuid IS 'Уникальный идентификатор заведения (UUID)';
COMMENT ON COLUMN cafe.restaurants.name IS 'Название заведения';
COMMENT ON COLUMN cafe.restaurants.type IS 'Тип заведения (кофейня, ресторан, бар, пиццерия)';
COMMENT ON COLUMN cafe.restaurants.menu IS 'Меню заведения в формате JSONB';
COMMENT ON COLUMN cafe.restaurants.created_at IS 'Дата и время создания записи';
COMMENT ON COLUMN cafe.restaurants.updated_at IS 'Дата и время последнего обновления записи';





-- Таблица менеджеров в схеме cafe
CREATE TABLE cafe.managers (
    manager_uuid UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_manager_phone UNIQUE (phone)
);

-- Комментарии к таблице и колонкам
COMMENT ON TABLE cafe.managers IS 'Таблица менеджеров заведений';
COMMENT ON COLUMN cafe.managers.manager_uuid IS 'Уникальный идентификатор менеджера (UUID)';
COMMENT ON COLUMN cafe.managers.name IS 'ФИО менеджера';
COMMENT ON COLUMN cafe.managers.phone IS 'Телефон менеджера';
COMMENT ON COLUMN cafe.managers.created_at IS 'Дата и время создания записи';
COMMENT ON COLUMN cafe.managers.updated_at IS 'Дата и время последнего обновления записи';

-- Индекс для быстрого поиска по телефону
CREATE INDEX idx_managers_phone ON cafe.managers(phone);




-- Добавление связи менеджера с рестораном (опционально) - нету в БД
ALTER TABLE cafe.restaurants 
ADD COLUMN manager_uuid UUID REFERENCES cafe.managers(manager_uuid) ON DELETE SET NULL;

COMMENT ON COLUMN cafe.restaurants.manager_uuid IS 'Ссылка на менеджера заведения';










_________________________________________________________________


-- Таблица периодов работы менеджеров в ресторанах
CREATE TABLE cafe.restaurant_manager_work_dates (
    restaurant_uuid UUID NOT NULL REFERENCES cafe.restaurants(restaurant_uuid) ON DELETE CASCADE,
    manager_uuid UUID NOT NULL REFERENCES cafe.managers(manager_uuid) ON DELETE CASCADE,
    work_start_date DATE NOT NULL,
    work_end_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Составной первичный ключ
    PRIMARY KEY (restaurant_uuid, manager_uuid),
    
    -- Проверка, что дата окончания не раньше даты начала
    CONSTRAINT valid_date_range CHECK (work_end_date IS NULL OR work_end_date >= work_start_date)
);

-- Комментарии к таблице и колонкам
COMMENT ON TABLE cafe.restaurant_manager_work_dates IS 'Таблица периодов работы менеджеров в заведениях';
COMMENT ON COLUMN cafe.restaurant_manager_work_dates.restaurant_uuid IS 'Ссылка на заведение';
COMMENT ON COLUMN cafe.restaurant_manager_work_dates.manager_uuid IS 'Ссылка на менеджера';
COMMENT ON COLUMN cafe.restaurant_manager_work_dates.work_start_date IS 'Дата начала работы менеджера в заведении';
COMMENT ON COLUMN cafe.restaurant_manager_work_dates.work_end_date IS 'Дата окончания работы менеджера в заведении (NULL если всё ещё работает)';
COMMENT ON COLUMN cafe.restaurant_manager_work_dates.created_at IS 'Дата и время создания записи';

-- Индексы для ускорения запросов
CREATE INDEX idx_work_dates_restaurant ON cafe.restaurant_manager_work_dates(restaurant_uuid);
CREATE INDEX idx_work_dates_manager ON cafe.restaurant_manager_work_dates(manager_uuid);
CREATE INDEX idx_work_dates_dates ON cafe.restaurant_manager_work_dates(work_start_date, work_end_date);


__________________________________________________________
-- Таблица продаж в схеме cafe
CREATE TABLE cafe.sales (
    sale_date DATE NOT NULL,
    restaurant_uuid UUID NOT NULL REFERENCES cafe.restaurants(restaurant_uuid) ON DELETE CASCADE,
    avg_check NUMERIC(10, 2) NOT NULL CHECK (avg_check >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Составной первичный ключ: дата + ресторан
    PRIMARY KEY (sale_date, restaurant_uuid)
);

-- Комментарии к таблице и колонкам
COMMENT ON TABLE cafe.sales IS 'Таблица ежедневных продаж заведений';
COMMENT ON COLUMN cafe.sales.sale_date IS 'Дата продаж';
COMMENT ON COLUMN cafe.sales.restaurant_uuid IS 'Ссылка на заведение';
COMMENT ON COLUMN cafe.sales.avg_check IS 'Средний чек за день в рублях';
COMMENT ON COLUMN cafe.sales.created_at IS 'Дата и время создания записи';

-- Индексы для ускорения запросов
CREATE INDEX idx_sales_restaurant ON cafe.sales(restaurant_uuid);
CREATE INDEX idx_sales_date ON cafe.sales(sale_date);
CREATE INDEX idx_sales_avg_check ON cafe.sales(avg_check);

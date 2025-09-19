-- Автор: Дарья Грибкова

-- Задача 1. Подготовка данных
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),   
-- Задача 2. Анализ рынка недвижимости Ленобласти
-- Посчитаем количество объявлений по населенным пунктам, среднюю стоимость квадратного метра и среднюю площадь квартиры:
table1 AS (
      SELECT c.city, 
             COUNT(f.id) AS total_flats,
             ROUND(AVG(last_price / total_area)::numeric, 2) AS avg_price_meter,
             ROUND(AVG(total_area)::numeric, 2) AS avg_total_area,
             ROUND(AVG(days_exposition)::numeric, 2) AS avg_days_exposition
      FROM real_estate.flats AS f
      LEFT JOIN real_estate.city AS c USING(city_id)
      LEFT JOIN real_estate.advertisement AS a USING(id)
      WHERE c.city != 'Санкт-Петербург'
      GROUP BY c.city
      HAVING COUNT(f.id) >= 50 --фильтруем только те города, где объявлений больше 50
      ORDER BY total_flats DESC),
-- Посчитаем количество снятых с продажи объявлений в населенных пунктах:
table2 AS (
      SELECT c.city, 
             COUNT(f.id) AS inactive_flats
      FROM real_estate.flats AS f
      LEFT JOIN real_estate.city AS c USING(city_id)
      LEFT JOIN real_estate.advertisement AS a USING(id)
      WHERE c.city != 'Санкт-Петербург' AND a.days_exposition IS NOT NULL
      GROUP BY c.city
      HAVING COUNT(f.id) >= 50 --фильтруем только те города, где объявлений больше 50
      ORDER BY inactive_flats DESC),
-- Посчитаем долю снятых объявлений от всех объявлений в разрезе по населенным пунктам и выведем предыдущие показатели:
table3 AS (
      SELECT t1.city,
             ROUND((inactive_flats::real / total_flats)::numeric, 2) AS share_inactive_flats,
             avg_price_meter,
             avg_total_area,
             avg_days_exposition
      FROM table1 AS t1
      JOIN table2 AS t2 USING(city)
      ORDER BY avg_days_exposition DESC)
SELECT *
FROM table3



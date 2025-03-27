/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Стрежнева Вера
 * Дата: 23.11.2024
*/

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l,
        percentile_disc(0.99) within group (order by last_price/total_area) AS price_limit_h,
        percentile_disc(0.01) WITHIN GROUP (ORDER BY last_price/total_area) AS price_limit_l 
    FROM real_estate.flats
    LEFT JOIN real_estate.advertisement USING(id)
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    LEFT JOIN real_estate.advertisement USING (id)
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
        AND last_price/total_area < (SELECT price_limit_h FROM limits)
        AND last_price/total_area > (SELECT price_limit_l FROM limits)
    )
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l,
        percentile_disc(0.99) within group (order by last_price/total_area) AS price_limit_h,
        percentile_disc(0.01) WITHIN GROUP (ORDER BY last_price/total_area) AS price_limit_l 
    FROM real_estate.flats
    LEFT JOIN real_estate.advertisement USING(id)
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    LEFT JOIN real_estate.advertisement USING (id)
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
        AND last_price/total_area < (SELECT price_limit_h FROM limits)
        AND last_price/total_area > (SELECT price_limit_l FROM limits)
    ),
flats_with_category AS(
SELECT *, CASE 
			WHEN days_exposition < 31 THEN 'до месяца'
			WHEN days_exposition >=31 AND days_exposition < 91 THEN 'до трех месяцев'
			when days_exposition>90 AND days_exposition <181 THEN 'до полугода'
			WHEN days_exposition > 180 THEN 'более полугода'
		END AS exposition_interval,
		CASE 
			WHEN city='Санкт-Петербург' THEN 'Санкт-Петербург'
			ELSE 'ЛенОбл' 
		END AS LOCATION,
		CASE 
			WHEN city='Колпино' THEN TYPE='город' AND type_id='F8EM'
		END
FROM real_estate.flats
LEFT JOIN real_estate.advertisement USING (id)
LEFT JOIN real_estate.type USING (type_id)
LEFT JOIN real_estate.city using(city_id)
WHERE id IN (SELECT * FROM filtered_id) AND days_exposition IS NOT NULL)
SELECT LOCATION, exposition_interval, count(id) AS num_of_exp,
		CASE 
			WHEN LOCATION='ЛенОбл' THEN round(count(id)::NUMERIC/(SELECT count(id) FROM flats_with_category WHERE LOCATION='ЛенОбл' AND type='город')*100,2)
			ELSE round(count(id)::NUMERIC/(SELECT count(id) FROM flats_with_category WHERE LOCATION='Санкт-Петербург')*100,2)
		END AS percantage,
		round(avg(last_price/total_area)::NUMERIC,2) AS avg_price, 
		round(avg(total_area)::NUMERIC,2) AS avg_area, 
		percentile_disc(0.5) WITHIN GROUP (ORDER BY floor) AS floor_median, 
		percentile_disc(0.5) WITHIN GROUP (ORDER BY rooms) AS rooms_median,
		percentile_disc(0.5) WITHIN GROUP (ORDER BY parks_around3000) AS parks_median 
FROM flats_with_category
WHERE type='город'
GROUP BY LOCATION, exposition_interval;


-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

--все запросы с with я еще в прошлый раз разделила, как и показано в твоем примере, возможно ошибка в отсутствии точки с запятой...

--активность объявлений о продаже
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l,
        percentile_disc(0.99) within group (order by last_price/total_area) AS price_limit_h,
        percentile_disc(0.01) WITHIN GROUP (ORDER BY last_price/total_area) AS price_limit_l 
    FROM real_estate.flats
    LEFT JOIN real_estate.advertisement USING(id)
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    LEFT JOIN real_estate.advertisement USING (id)
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
        AND last_price/total_area < (SELECT price_limit_h FROM limits)
        AND last_price/total_area > (SELECT price_limit_l FROM limits)
    ),
exposition AS (SELECT extract('month' FROM first_day_exposition) AS exp_month, count(id) AS cnt, avg(last_price/total_area) AS avg_price, avg(total_area) AS avg_area, ntile(3) over (ORDER BY count(id) desc) AS rank
FROM real_estate.flats
LEFT JOIN real_estate.advertisement using(id) -- в данном случае разлчия между LEFT и INNER нет, так как присоединение по идентификаторам, которые присутствуют в обеих таблицах, поэтому условие на ненулевое значение days_exposition в любом случае нужно
WHERE id IN (SELECT * FROM filtered_id) AND days_exposition IS NOT NULL 
GROUP BY exp_month)
SELECT *, CASE 
	WHEN RANK=1 THEN 'Высокая активность'
	WHEN RANK=2 THEN 'Средняя активность'
	ELSE 'Низкая активность'
END
FROM exposition;

--активность снятия объявлений
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l,
        percentile_disc(0.99) within group (order by last_price/total_area) AS price_limit_h,
        percentile_disc(0.01) WITHIN GROUP (ORDER BY last_price/total_area) AS price_limit_l 
    FROM real_estate.flats
    LEFT JOIN real_estate.advertisement USING(id)
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    LEFT JOIN real_estate.advertisement USING (id)
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
        AND last_price/total_area < (SELECT price_limit_h FROM limits)
        AND last_price/total_area > (SELECT price_limit_l FROM limits)
    ),
buy AS (SELECT extract('month' FROM first_day_exposition+days_exposition*'1 day'::INTERVAL) AS buy_month, count(id) AS cnt, avg(last_price/total_area) AS avg_price, avg(total_area) AS avg_area, ntile(3) over(ORDER BY count(id) desc) AS rank
FROM real_estate.flats
LEFT JOIN real_estate.advertisement using(id)
WHERE id IN (SELECT * FROM filtered_id) AND days_exposition IS NOT NULL
GROUP BY buy_month)
SELECT *, CASE 
	WHEN RANK=1 THEN 'Высокая активность'
	WHEN RANK=2 THEN 'Средняя активность'
	ELSE 'Низкая активность'
END
FROM buy;

-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

--вычисление top-10
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l,
        percentile_disc(0.99) within group (order by last_price/total_area) AS price_limit_h,
        percentile_disc(0.01) WITHIN GROUP (ORDER BY last_price/total_area) AS price_limit_l 
    FROM real_estate.flats
    LEFT JOIN real_estate.advertisement USING(id)
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    LEFT JOIN real_estate.advertisement USING (id)
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
        AND last_price/total_area < (SELECT price_limit_h FROM limits)
        AND last_price/total_area > (SELECT price_limit_l FROM limits)
    ),
flats_with_category AS(
SELECT *, CASE 
			WHEN days_exposition < 31 THEN 'до месяца'
			WHEN days_exposition >=31 AND days_exposition < 91 THEN 'до трех месяцев'
			when days_exposition>90 AND days_exposition <181 THEN 'до полугода'
			WHEN days_exposition > 180 THEN 'более полугода'
		END AS exposition_interval,
		CASE 
			WHEN city='Санкт-Петербург' THEN 'Санкт-Петербург'
			ELSE 'ЛенОбл' 
		END AS LOCATION
FROM real_estate.flats
LEFT JOIN real_estate.advertisement USING (id)
LEFT JOIN real_estate.type USING (type_id)
LEFT JOIN real_estate.city using(city_id)
WHERE id IN (SELECT * FROM filtered_id))
SELECT city, count(id) AS cnt
FROM flats_with_category
WHERE LOCATION='ЛенОбл'
GROUP BY city
ORDER BY cnt DESC
LIMIT 10;

--рассчет доли снятых объявлений и средних значений показателей
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l,
        percentile_disc(0.99) within group (order by last_price/total_area) AS price_limit_h,
        percentile_disc(0.01) WITHIN GROUP (ORDER BY last_price/total_area) AS price_limit_l 
    FROM real_estate.flats
    LEFT JOIN real_estate.advertisement USING(id)
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    LEFT JOIN real_estate.advertisement USING (id)
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
        AND last_price/total_area < (SELECT price_limit_h FROM limits)
        AND last_price/total_area > (SELECT price_limit_l FROM limits)
    ),
flats_with_category AS(
SELECT *, CASE 
			WHEN days_exposition < 31 THEN 'до месяца'
			WHEN days_exposition >=31 AND days_exposition < 91 THEN 'до трех месяцев'
			when days_exposition>90 AND days_exposition <181 THEN 'до полугода'
			WHEN days_exposition > 180 THEN 'более полугода'
		END AS exposition_interval,
		CASE 
			WHEN city='Санкт-Петербург' THEN 'Санкт-Петербург'
			ELSE 'ЛенОбл' 
		END AS LOCATION
FROM real_estate.flats
LEFT JOIN real_estate.advertisement USING (id)
LEFT JOIN real_estate.type USING (type_id)
LEFT JOIN real_estate.city using(city_id)
WHERE id IN (SELECT * FROM filtered_id)),
buy_len AS (
SELECT city, count(id) AS cnt
FROM flats_with_category
WHERE LOCATION='ЛенОбл' AND days_exposition IS NOT NULL
GROUP BY city),
exp_len AS (SELECT city, count(id) AS cnt_exp, round(avg(last_price/total_area)::NUMERIC,2) AS avg_price, 
		round(avg(total_area)::NUMERIC,2) AS avg_area
FROM flats_with_category
WHERE LOCATION='ЛенОбл'
GROUP BY city)
SELECT city, cnt_exp, cnt, round(cnt::NUMERIC/cnt_exp*100,2) AS percentage, avg_price, avg_area
FROM buy_len
JOIN exp_len using(city)
WHERE city IN ('Мурино','Кудрово','Всеволожск','Шушары','Парголово','Пушкин','Сестрорецк','Колпино','Петергоф','Новое Девяткино')
ORDER BY percentage DESC;

--скорость продажи
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l,
        percentile_disc(0.99) within group (order by last_price/total_area) AS price_limit_h,
        percentile_disc(0.01) WITHIN GROUP (ORDER BY last_price/total_area) AS price_limit_l 
    FROM real_estate.flats
    LEFT JOIN real_estate.advertisement USING(id)
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    LEFT JOIN real_estate.advertisement USING (id)
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
        AND last_price/total_area < (SELECT price_limit_h FROM limits)
        AND last_price/total_area > (SELECT price_limit_l FROM limits)
    ),
flats_with_category AS(
SELECT *, CASE 
			WHEN days_exposition < 31 THEN 'до месяца'
			WHEN days_exposition >=31 AND days_exposition < 91 THEN 'до трех месяцев'
			when days_exposition>90 AND days_exposition <181 THEN 'до полугода'
			WHEN days_exposition > 180 THEN 'более полугода'
		END AS exposition_interval,
		CASE 
			WHEN city='Санкт-Петербург' THEN 'Санкт-Петербург'
			ELSE 'ЛенОбл' 
		END AS LOCATION
FROM real_estate.flats
LEFT JOIN real_estate.advertisement USING (id)
LEFT JOIN real_estate.type USING (type_id)
LEFT JOIN real_estate.city using(city_id)
WHERE id IN (SELECT * FROM filtered_id)),
--первое решение, что пришло в голову, по-другому как сделать, пока не догадалась:)
interval_city AS (SELECT city,exposition_interval, count(id) over(PARTITION BY city) AS cnt, count(id) over(PARTITION BY city,exposition_interval) AS cnt_in,count(id) over(PARTITION BY city,exposition_interval)::NUMERIC/count(id) over(PARTITION BY city) AS perc
FROM flats_with_category
WHERE city IN ('Мурино','Кудрово','Всеволожск','Шушары','Парголово','Пушкин','Сестрорецк','Колпино','Петергоф','Новое Девяткино') AND days_exposition IS NOT null
)
SELECT city, exposition_interval, avg(cnt) AS total_exp, avg(cnt_in) exp_interval_cnt, round(avg(perc)*100,2) AS percentage
FROM interval_city
GROUP BY city, exposition_interval
ORDER BY exposition_interval, percentage DESC;


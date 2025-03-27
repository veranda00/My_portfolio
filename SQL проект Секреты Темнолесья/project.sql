/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: 
 * Дата: 
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT count(id) AS total_users, 
	   SUM(payer) AS payers,
	   round(sum(payer)::numeric/count(id),4) AS payers_percentage
FROM fantasy.users

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT race_id, 
	   race,
       count(id) AS total_users,
       sum(payer) AS payers,
       round(sum(payer)::numeric/count(id),4) as payers_percentage
FROM fantasy.users 
JOIN fantasy.race using(race_id)
GROUP BY race_id, race
ORDER BY payers_percentage DESC

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
select count(transaction_id) as total_purch,
		sum(amount) as total_amount, 
	    min(amount) as min_amount, 
	    min(amount) FILTER (WHERE amount != 0)  AS min_no_empty_amount,
	    max(amount) as max_amount,
	    avg(amount) as avg_amount,
	    percentile_disc(0.5) within group(order by amount) as amount_median,
	    stddev(amount) as std_amount
from fantasy.events 

-- 2.2: Аномальные нулевые покупки:
SELECT count(*) AS total_amount, 
		COUNT(amount) FILTER (WHERE amount = 0)  AS empty_amount,
		round(COUNT(amount) FILTER (WHERE amount = 0)::numeric / count(*),3) AS empty_percentage
FROM fantasy.events

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
SELECT 'payer' AS user_type,
count(u.id) AS total_users,
avg(events_count) AS avg_buy_per_user,
avg(sum_amount) AS avg_amount_per_user	
FROM fantasy.users AS u
LEFT JOIN (
    SELECT e.id,
    		count(transaction_id) AS events_count,
    		sum(amount) AS sum_amount
	FROM fantasy.events AS e
	LEFT JOIN fantasy.users AS u using(id)
	WHERE payer=1 AND amount!=0
	GROUP BY e.id
) AS e using(id)
WHERE u.payer = 1 
UNION
SELECT 'not_payer' AS user_type,
count(u.id) AS total_users,
avg(events_count) AS avg_buy_per_user,
avg(sum_amount) AS avg_amount_per_user	
FROM fantasy.users AS u
LEFT JOIN (
    SELECT e.id,
    		count(transaction_id) AS events_count,
    		sum(amount) AS sum_amount
	FROM fantasy.events AS e
	LEFT JOIN fantasy.users AS u using(id)
	WHERE payer=0 AND amount!=0
	GROUP BY e.id
) AS e using(id)
WHERE u.payer = 0 

-- 2.4: Популярные эпические предметы:
-- Напишите ваш запрос здесь
SELECT events.item_code, 
game_items,
count(events.item_code) AS item_count, 
round(count(events.item_code)::numeric/(SELECT count(*) FROM fantasy.events),5) AS item_part,
round(count(DISTINCT id)::numeric/(SELECT count(*) FROM fantasy.users),5) AS item_users
FROM fantasy.events
LEFT JOIN fantasy.items using(item_code)
WHERE amount!=0
GROUP BY item_code,game_items
ORDER BY item_count DESC

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
WITH total_user_race AS(
SELECT race_id, count(DISTINCT id) AS total_users
from fantasy.users
GROUP BY race_id),
buyers_race as(
SELECT race_id, 
	   count(DISTINCT e.id) AS buy_users,
	   COUNT(DISTINCT e.id) FILTER (WHERE amount != 0 AND payer=1) AS pay,
	   round((COUNT(DISTINCT e.id) FILTER (WHERE amount != 0 AND payer=1))::NUMERIC/count(DISTINCT e.id),4) AS payers,
	   avg(amount) AS avg_amount
FROM fantasy.users AS u
RIGHT JOIN fantasy.events AS e USING(id)
WHERE amount !=0
GROUP BY race_id),
act_user AS (
SELECT race_id, avg(trans_total) AS avg_event_per_user, avg(sum_amount) AS avg_sum_amount_per_user
FROM fantasy.users AS u
JOIN (
SELECT race_id, e.id, 
	count(transaction_id) AS trans_total, 
	sum(amount) AS sum_amount
FROM fantasy.users
JOIN fantasy.events AS e USING(id)
WHERE amount!=0
GROUP BY race_id, e.id) AS tt USING(race_id)
GROUP BY race_id)
SELECT tu.race_id, race, total_users, buy_users, round(buy_users::NUMERIC/total_users,4) AS buyers_percent, payers, avg_event_per_user, avg_amount, avg_sum_amount_per_user
FROM total_user_race AS tu
JOIN buyers_race using(race_id)
JOIN act_user using(race_id)
LEFT JOIN fantasy.race using(race_id)
ORDER BY total_users

-- Задача 2: Частота покупок
-- Напишите ваш запрос здесь
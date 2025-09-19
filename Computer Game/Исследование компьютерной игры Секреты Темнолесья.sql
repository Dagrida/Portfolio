/* Проект «Секреты Тёмнолесья»
 * Автор: Дарья Грибкова
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1 Доля платящих пользователей по всем данным:
SELECT (SELECT COUNT(*)
       FROM fantasy.users) AS total_users, --вывела общее кол-во пользователей
       COUNT(*) AS payer_users, --вывела пользователей, которые заплатили
       ROUND(COUNT(*)::numeric / (
       SELECT COUNT(id)
       FROM fantasy.users), 2) AS share_payer_users --посчитала долю заплативших пользователей
FROM fantasy.users
WHERE payer = 1

-- 1.2 Доля платящих пользователей в разрезе расы персонажа:
WITH table1 AS (SELECT r.race, --посчитала общую долю пользователей по расам
       COUNT(id) AS total_users
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r USING(race_id)
GROUP BY r.race),
table2 AS (SELECT r.race, --посчитала долю заплативших пользователей по расам
       COUNT(id) AS payer_users
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r USING(race_id)
WHERE u.payer = 1
GROUP BY r.race)
SELECT t1.race, --вывела по расам всех пользователей, заплативших пользователей и долю заплативших пользоваталей
       t1.total_users,
       t2.payer_users,
       t2.payer_users::real / t1.total_users AS share_payer_users 
FROM table1 AS t1
LEFT JOIN table2 AS t2 ON t1.race = t2.race

-- Задача 2. Исследование внутриигровых покупок
-- 2.1 Статистические показатели по полю amount:
SELECT COUNT(transaction_id) AS count_transaction, --общее кол-во покупок
       SUM(amount) AS sum_amount, --общая сумма покупок
       MIN(amount) AS min_amount, --минимальная стоимость покупки
       MAX(amount) AS max_amount, --максимальная стоимость покупки
       ROUND(AVG(amount)::numeric, 2) AS avg_amount, --средняя стоимость всех покупок
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount -- медиана
FROM fantasy.events

-- 2.2 Аномальные нулевые покупки:
SELECT (SELECT COUNT(transaction_id)
        FROM fantasy.events) AS total_amount,
        COUNT(transaction_id) AS ziro_amount,
        ROUND(COUNT(transaction_id)::numeric / (SELECT COUNT(transaction_id)
        FROM fantasy.events), 5) AS share_ziro_amount
FROM fantasy.events
WHERE amount = 0

-- 2.3 Сравнительный анализ активности платящих и неплатящих игроков:
SELECT COUNT(id) AS count_id,
       ROUND(AVG(count_events)::numeric, 2) AS avg_events, --среднее по кол-ву покупок player=1
       ROUND(AVG(sum_amount)::numeric, 2) AS avg_amount --среднее по сумме покупок player=1
FROM (
SELECT u.id,
       COUNT(e.transaction_id) AS count_events, --посчитала кол-во покупок по каждому player=1
       SUM(e.amount) AS sum_amount --посчитала сумму покупок по каждому player=1
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e USING(id)
WHERE u.payer = 1 AND e.amount <> 0 --отфильтровала по платящим игрокам и по нулевой стоимости
GROUP BY u.id) AS table1
UNION --соединила две таблицы для наглядного анализа
SELECT COUNT(id) AS count_id,
       ROUND(AVG(count_events)::numeric, 2) AS avg_events, --среднее по кол-ву покупок player=0
       ROUND(AVG(sum_amount)::numeric, 2) AS avg_amount --среднее по сумме покупок player=0
FROM (
SELECT u.id,
       COUNT(e.transaction_id) AS count_events, --посчитала кол-во покупок по каждому player=0
       SUM(e.amount) AS sum_amount --посчитала сумму покупок по каждому player=0
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e USING(id)
WHERE u.payer = 0 AND e.amount <> 0 --отфильтровала по не платящим игрокам и по нулевой стоимости
GROUP BY u.id) AS table2

-- 2.4 Популярные эпические предметы:
WITH table1 AS ( --посчитала отдельно по каждому предмету кол-во покупок в абсолютно и относительном значении
SELECT i.game_items,
       COUNT(e.transaction_id) AS count_transactions,
       COUNT(e.transaction_id)::real / (SELECT COUNT(*)
FROM fantasy.events) AS share_count_transaction
FROM fantasy.events AS e
LEFT JOIN fantasy.items AS i USING(item_code)
GROUP BY i.game_items),
table2 AS ( --посчитала отдельно по каждому предмету долю игрок, которые купили предмет хоть раз, от общей доли игроков
SELECT i.game_items,
       COUNT(DISTINCT e.id) AS count_users,
       COUNT(DISTINCT e.id)::real / (SELECT COUNT(DISTINCT id)
FROM fantasy.events) AS share_count_users
FROM fantasy.events AS e
LEFT JOIN fantasy.items AS i USING(item_code)
LEFT JOIN fantasy.users AS u USING(id)
WHERE e.amount <> 0
GROUP BY i.game_items)
SELECT t1.game_items, --вывела данные из двух СТЕ
       t1.count_transactions,
       t1.share_count_transaction,
       t2.share_count_users
FROM table1 AS t1
LEFT JOIN table2 AS t2 USING(game_items)
ORDER BY t1.count_transactions DESC

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- Общее количество зарегистрированных игроков:
WITH table1 AS (
SELECT r.race,
       COUNT(u.id) AS count_users
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r USING(race_id)
GROUP BY r.race),
-- Количество игроков, которые совершают внутриигровые покупки, и их доля от общего количества:
table2 AS (
SELECT r.race,
       COUNT(DISTINCT e.id) AS count_amount_users,
       ROUND(COUNT(DISTINCT e.id)::numeric / (
       SELECT COUNT(DISTINCT u.id)
       FROM fantasy.users AS u), 2) AS share_count_payer_users --число купивших игроков расы делим на общее количествои игроков расы
FROM fantasy.events AS e
LEFT JOIN fantasy.users AS u USING(id)
LEFT JOIN fantasy.race AS r USING(race_id)
GROUP BY r.race),
-- Доля платящих игроков от количества игроков, которые совершили покупки:
table3 AS (
SELECT r.race,
       COUNT(DISTINCT e.id) AS count_payer_users,
       ROUND(COUNT(DISTINCT e.id)::numeric / (
       SELECT COUNT(DISTINCT e.id)
       FROM fantasy.events AS e), 2) AS share_count_payer_users_amount --поделила на count_amount_users
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r USING(race_id)
RIGHT JOIN fantasy.events AS e USING(id)
WHERE u.payer = 1
GROUP BY r.race),
--  Cреднее количество покупок на одного игрок, средняя стоимость одной покупки на одного игрока и суммарная стоимость одной покупки на одного игрока:
table4 AS (
SELECT u.id,
       r.race,
       COUNT(e.transaction_id) AS count_transactions_user, --кол-во покупок у каждого игрока
       AVG(e.amount) AS avg_amount_user, --средняя стоимость покупки на игрока
       SUM(e.amount) AS sum_amount_user --сумма покупок на одного игрока
FROM fantasy.users AS u
JOIN fantasy.race AS r USING(race_id)
JOIN fantasy.events AS e USING(id)
GROUP BY u.id, r.race),
table5 AS (
SELECT DISTINCT race,
       AVG(count_transactions_user) OVER(PARTITION BY race) AS count_transactions_race, --среднее кол-во покупок на одного игрока по расам
       AVG(sum_amount_user) OVER(PARTITION BY race) / AVG(count_transactions_user) OVER(PARTITION BY race) AS avg_amount_race, --средняя стоимость попукпи на игрока по расам
       AVG(sum_amount_user) OVER(PARTITION BY race) AS sum_amount_race --средняя сумма покупок на одного игрока по расама
FROM table4)
SELECT DISTINCT t1.race,
       t1.count_users,
       t2.count_amount_users,
       t2.share_count_payer_users,
       t3.share_count_payer_users_amount,
       t5.count_transactions_race,
       t5.avg_amount_race,
       t5.sum_amount_race
FROM table1 AS t1
JOIN table2 AS t2 USING(race)
JOIN table3 AS t3 USING(race)
JOIN table4 AS t4 USING(race)
JOIN table5 AS t5 USING(race)

-- Задача 2: Частота покупок
-- Кол-во покупок на каждого пользователя и следующая дата покупки для дальнейших вычислений:
WITH table1 AS (
SELECT DISTINCT id,
       date::date,
       COUNT(transaction_id) OVER (PARTITION BY id) AS total_transactions,
       LEAD(date) OVER (PARTITION BY id ORDER BY date) AS next_date
FROM fantasy.events
ORDER BY id, date),
-- Интервал между датами покупок и ранг по интервалу на 3 группы:
table2 AS (
SELECT id,
       date,
       total_transactions,
       next_date,
       next_date::date - date::date AS interval_date,
       NTILE(3) OVER (ORDER BY (next_date::date - date::date) DESC) AS RANK   
FROM table1
WHERE total_transactions >= 25
ORDER BY id, date),
-- Наименование статуса частоты покупок в зависимости от ранга:
table3 AS (
SELECT id,
       date,
       total_transactions,
       interval_date,
       CASE
       	WHEN rank = 1 THEN 'низкая частота'
       	WHEN rank = 2 THEN 'умеренная частота'
       	WHEN rank = 3 THEN 'высокая частота'
       END AS rank
FROM table2
ORDER BY id, date),
-- Кол-во игроков, которые совершили покупки, по каждой группе:
-- 1.1 Высокая частота:
table1_group1 AS (
SELECT COUNT(t3.id) AS count_user_amount
FROM table3 AS t3
LEFT JOIN fantasy.events AS e USING(id)
WHERE t3.rank = 'высокая частота' AND e.amount <> 0),
--1.2 Умеренная частота:
table1_group2 AS (
SELECT COUNT(t3.id) AS count_user_amount
FROM table3 AS t3
LEFT JOIN fantasy.events AS e USING(id)
WHERE t3.rank = 'умеренная частота' AND e.amount <> 0),
--1.3 Низкая частота:
table1_group3 AS (
SELECT COUNT(t3.id) AS count_user_amount
FROM table3 AS t3
LEFT JOIN fantasy.events AS e USING(id)
WHERE t3.rank = 'низкая частота' AND e.amount <> 0),
-- Кол-во платящих игроков, совершивших покупки, и их доля от общего количества игроков, совершивших покупку:
-- 2.1 Высокая частота:
table2_group1 AS (
SELECT COUNT(t3.id) AS count_user_amount_payer,
       COUNT(t3.id)::real / (SELECT count_user_amount
                       FROM table1_group1) AS share_count_user_amount_payer
FROM table3 AS t3
LEFT JOIN fantasy.events AS e USING(id)
LEFT JOIN fantasy.users AS u ON e.id = u.id
WHERE e.amount <> 0 AND u.payer = 1 AND t3.rank = 'высокая частота'),
--2.2 Умеренная частота:
table2_group2 AS (
SELECT COUNT(t3.id) AS count_user_amount_payer,
       COUNT(t3.id)::real / (SELECT count_user_amount
                       FROM table1_group2) AS share_count_user_amount_payer
FROM table3 AS t3
LEFT JOIN fantasy.events AS e USING(id)
LEFT JOIN fantasy.users AS u ON e.id = u.id
WHERE e.amount <> 0 AND u.payer = 1 AND t3.rank = 'умеренная частота'),
--2.3 Низкая частота:
table2_group3 AS (
SELECT COUNT(t3.id) AS count_user_amount_payer,
       COUNT(t3.id)::real / (SELECT count_user_amount
                       FROM table1_group3) AS share_count_user_amount_payer
FROM table3 AS t3
LEFT JOIN fantasy.events AS e USING(id)
LEFT JOIN fantasy.users AS u ON e.id = u.id
WHERE e.amount <> 0 AND u.payer = 1 AND t3.rank = 'низкая частота'),
-- Среднее кол-во покупок на одного игрока:
-- 3.1 Высокая частота:
table3_group1_1 AS (--считаем кол-во покупок на каждого клиента в пределах одной группы по высокой частоте покупок
SELECT id,
       total_transactions AS count_transaction_high
FROM table3
WHERE RANK = 'высокая частота'),
table3_group1_2 AS (
SELECT ROUND(AVG(count_transaction_high), 2) AS avg_count_transaction_high --считаем среднее кол-во покупок на одного клиента в пределах группы по высокой частоте покупок
FROM table3_group1_1),
-- 3.2 Умеренная частота:
table3_group2_1 AS (--считаем кол-во покупок на каждого клиента в пределах одной группы по умеренной частоте покупок
SELECT id,
       total_transactions AS count_transaction_middle
FROM table3
WHERE RANK = 'умеренная частота'),
table3_group2_2 AS (
SELECT ROUND(AVG(count_transaction_middle), 2) AS avg_count_transaction_middle --считаем среднее кол-во покупок на одного клиента в пределах группы по умеренной покупок
FROM table3_group2_1),
-- 3.3 Низкая частота:
table3_group3_1 AS (--считаем кол-во покупок на каждого клиента в пределах одной группы по низкой частоте покупок
SELECT id,
       total_transactions AS count_transaction_low
FROM table3
WHERE RANK = 'низкая частота'),
table3_group3_2 AS (
SELECT ROUND(AVG(count_transaction_low), 2) AS avg_count_transaction_low --считаем среднее кол-во покупок на одного клиента в пределах группы по низкой частоте покупок
FROM table3_group3_1),
-- Среднее кол-во дней между покупками на одного игрока:
-- 4.1 Высокая частота:
table4_group1 AS (
SELECT ROUND(AVG(interval_date), 2)
FROM table3
WHERE rank = 'высокая частота'),
-- 4.2 Умеренная частота:
table4_group2 AS (
SELECT ROUND(AVG(interval_date), 2)
FROM table3
WHERE rank = 'умеренная частота'),
-- 4.3 Низкая частота:
table4_group3 AS (
SELECT ROUND(AVG(interval_date), 2)
FROM table3
WHERE rank = 'низкая частота')
SELECT *
FROM table2
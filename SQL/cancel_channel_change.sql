DROP TABLE IF EXISTS user_id_list;
CREATE TEMPORARY TABLE IF NOT EXISTS user_id_list (user_id UUID);

INSERT INTO user_id_list (user_id)
SELECT user_id
FROM ekd_id.person
WHERE CONCAT(person.last_name, ' ', person.first_name, ' ', person.patronymic) IN ('' ||
                                                                                   'ФИО' ||
                                                                                   '');


SELECT state, created_date, finished_date, 'task' AS type
FROM ekd_ca.nqes_channel_change_task
WHERE user_id IN (SELECT * FROM user_id_list)
UNION ALL
SELECT state, created_date, finished_date, 'request' AS type
FROM ekd_ekd.nqes_channel_change_request
WHERE user_id IN (SELECT * FROM user_id_list);

UPDATE ekd_ca.nqes_channel_change_task
SET state = 'USER_REJECTED', finished_date = now()
WHERE finished_date is null
  AND user_id IN (SELECT * FROM user_id_list);

UPDATE ekd_ekd.nqes_channel_change_request
SET state = 'USER_REJECTED', finished_date = now()
WHERE finished_date is null
  AND user_id IN (SELECT * FROM user_id_list);

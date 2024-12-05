with
    with_stats AS (
        SELECT concat(last_name, ' ', first_name, ' ', patronymic) AS "ФИО"
             , employee.client_user_id
             , legal_entity.short_name  "ЮЛ"
             , employee_position.name   "Должность"
             , client_department.name   "Отдел"
             , vacation.start_date      "Начало"
             , vacation.end_date        "Окончание"
             , CASE
                   WHEN vacation.approved_date IS NOT NULL AND start_date IS NOT NULL
                       THEN 'Согласован'
                   WHEN start_date IS NOT NULL
                       THEN 'В процессе'
               END as                   "Статус"

        FROM ekd_ekd.vacation
        FULL JOIN ekd_ekd.employee ON vacation.planning_employee_id = employee.id
        JOIN ekd_ekd.legal_entity ON employee.legal_entity_id = legal_entity.id
        LEFT JOIN ekd_ekd.employee_position ON employee.employee_position_id = employee_position.id
        LEFT JOIN ekd_ekd.client_department ON employee.client_department_id = client_department.id
        JOIN ekd_ekd.client_user ON employee.client_user_id = client_user.id
        JOIN ekd_id.person ON person.user_id = client_user.user_id
),
    -- Смотрим у кого заполнен отпуск
    with_vacs AS (
            SELECT client_user_id, MAX("Статус") as max_status
            FROM with_stats
            GROUP BY client_user_id
)

SELECT with_stats."ФИО"
     , "Должность"
     , "Отдел"
     , "ЮЛ"
     , CASE
           WHEN max_status IS NULL
               THEN 'Не заполнен'   -- Присваиваем всем у кого не заполнен отпуск
           ELSE max_status
       END as "Статус"

FROM with_stats
JOIN with_vacs  ON with_stats.client_user_id = with_vacs.client_user_id
GROUP BY with_stats."ФИО", "Должность", "Отдел", "ЮЛ", with_stats.client_user_id, max_status
ORDER BY "ФИО";

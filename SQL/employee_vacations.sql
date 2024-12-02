CREATE VIEW v_vacations AS
    SELECT last_name "Фамилия",
           first_name "Имя",
           patronymic "Отчество",
           employee_position.name "Должность",
           client_department.name "Отдел",
           legal_entity.short_name "ЮЛ",
           vacation.start_date "Начало",
           vacation.end_date "Окончание",
           CASE
               WHEN vacation.approved_date IS NOT NULL AND start_date IS NOT NULL THEN 'Согласован'
               WHEN start_date IS NULL THEN 'Не заполнен'
               ELSE 'В процессе'
           END as "Статус"
    FROM ekd_ekd.vacation
        FULL JOIN ekd_ekd.employee ON vacation.planning_employee_id = employee.id
        JOIN ekd_ekd.legal_entity ON employee.legal_entity_id = legal_entity.id
        FULL JOIN ekd_ekd.employee_vacation_planning ON employee.id = employee_vacation_planning.employee_id
        LEFT JOIN ekd_ekd.employee_position ON employee.employee_position_id = employee_position.id
        LEFT JOIN ekd_ekd.client_department ON employee.client_department_id = client_department.id
        FULL JOIN ekd_ekd.client_user ON employee.client_user_id = client_user.id
        FULL JOIN ekd_id.person ON person.user_id = client_user.user_id;


SELECT "Фамилия", "Имя", "Отчество", "Должность", "Отдел", "ЮЛ", "Статус"
FROM v_vacations
WHERE "Статус" != 'Не заполнен'
GROUP BY "Фамилия", "Имя", "Отчество", "Должность", "Отдел", "ЮЛ", "Статус"
ORDER BY "Фамилия", "Имя", "Отчество";

WITH with_vacs AS (
            SELECT concat("Фамилия", "Имя", "Отчество" )
            FROM v_vacations
            WHERE "Начало" IS NOT NULL)

SELECT "Фамилия", "Имя", "Отчество", "Должность", "Отдел", "ЮЛ", "Статус"
FROM v_vacations
WHERE concat("Фамилия", "Имя", "Отчество") NOT IN (SELECT * FROM with_vacs)
GROUP BY "Фамилия", "Имя", "Отчество", "Должность", "Отдел", "ЮЛ", "Статус"
ORDER BY "Фамилия", "Имя", "Отчество";


with
    with_fio AS (
        SELECT user_id
        FROM ekd_id.person
        WHERE CONCAT(last_name, ' ', first_name, ' ', patronymic) = '' ||
                                                                    'ФИО'
    ),
    with_le AS (
        SELECT id
        FROM ekd_ekd.legal_entity
        WHERE short_name ilike '%' ||
                                                                     'ЮЛ' ||
                               '%'
    ),
    with_cu AS (
        SELECT id
        FROM ekd_ekd.client_user
        WHERE user_id = (SELECT user_id FROM with_fio)
    ),
    with_emp AS (
        SELECT employee_position_id, client_department_id
        FROM ekd_ekd.employee
        WHERE client_user_id = (SELECT id FROM with_cu)
        ORDER BY employee_position_id, client_department_id DESC
        LIMIT 1
    )

INSERT INTO ekd_ekd.employee(client_user_id,
                             employee_position_id,
                             client_department_id,
                             legal_entity_id)
SELECT
    (SELECT id FROM with_cu)    AS client_user_id,
    (SELECT employee_position_id FROM with_emp),
    (SELECT client_department_id FROM with_emp),
    (SELECT id FROM with_le)    AS legal_entity_id;


SELECT concat(person.last_name, ' ', person.first_name, ' ', person.patronymic), legal_entity.short_name, employee_position.name
FROM ekd_ekd.employee
LEFT JOIN ekd_ekd.legal_entity ON employee.legal_entity_id = legal_entity.id
LEFT JOIN ekd_ekd.employee_position ON employee.employee_position_id = employee_position.id
JOIN ekd_ekd.client_user ON employee.client_user_id = client_user.id
JOIN ekd_id.person ON client_user.user_id = person.user_id
WHERE employee.created_date <= NOW()
ORDER BY employee.created_date DESC LIMIT 1;


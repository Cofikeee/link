SET SEARCH_PATH TO ekd_ekd;
BEGIN;
DO $$
DECLARE
    -- Инициализируем необходимые переменные
    empKeep uuid;           -- последний выгруженный employee_id сотрудинка, его оставляем
    empRemove uuid;         -- более ранний employee_id сотрудинка, его будем удалять
    epmDupRecord record;    -- уникальная связка двух вышеуказанных employee_id
BEGIN

    -- Создаём временную таблицу с дублями (emp_keep, emp_remove)
    CREATE TEMP TABLE temp_emp_dups AS
        WITH dups AS (
                SELECT client_user_id
                     , legal_entity_id
                     , client_department_id
                     , employee_position_id
                     , COUNT(1)              AS dups_count
                     , COUNT(dismissed_date) AS dissmiss_count
                FROM ekd_ekd.employee
                GROUP BY client_user_id, legal_entity_id, client_department_id, employee_position_id
        ),
            dups_filtered AS (
                SELECT *
                FROM dups
                WHERE dups_count > 1
                  AND dups_count != dissmiss_count
        ),
            ordered_list AS (
                SELECT id
                     , d.client_user_id
                     , d.client_department_id
                     , d.employee_position_id
                     , external_id
                     , created_date
                     , d.legal_entity_id
                     , dismissed_date
                     , RANK() OVER (PARTITION BY d.client_user_id, d.client_department_id, d.employee_position_id ORDER BY created_date DESC) AS rank
                FROM ekd_ekd.employee e
                    JOIN dups_filtered d ON d.client_user_id = e.client_user_id
                                                AND d.employee_position_id = e.employee_position_id
                                               AND d.legal_entity_id = e.legal_entity_id
                )
            SELECT a.id AS emp_keep
                 , b.id AS emp_remove
            FROM ordered_list a
                JOIN ordered_list b ON a.client_user_id = b.client_user_id
                                           AND a.client_department_id = b.client_department_id
                                           AND a.employee_position_id = b.employee_position_id
            WHERE a.rank = 1
              AND b.rank != 1;

    -- Создаём временную таблицу со значениями normative_act_id из normative_act_document, где employee_id=emp_keep
    CREATE TEMP TABLE temp_lna AS
        SELECT normative_act_id, employee_id
        FROM normative_act_document
        WHERE employee_id in (SELECT emp_keep FROM temp_emp_dups);

    -- Создаём временную таблицу с employee_id=emp_keep, которые есть в legal_entity_employee_role
     CREATE TEMP TABLE temp_roles AS
         SELECT employee_role_id, employee_id
         FROM legal_entity_employee_role
         WHERE employee_id in (SELECT emp_keep FROM temp_emp_dups);

    -- Создаём временную таблицу с employee_id=emp_keep, которые есть в temp_vacations
    CREATE TEMP TABLE temp_vacations AS
         SELECT planning_year, employee_id
         FROM employee_vacation_planning
         WHERE employee_id in (SELECT emp_keep FROM temp_emp_dups);

    -- Запуск цикла, в котором построчно проходимся по всем дубликатам
    FOR epmDupRecord IN
        SELECT * FROM temp_emp_dups
    LOOP
        empKeep := epmDupRecord.emp_keep;
        empRemove := epmDupRecord.emp_remove;

        -- Стандартные апдейты в связанных таблицах. Присваиваем emp_keep, записям с emp_remove
        UPDATE application SET employee_id = empKeep WHERE employee_id = empRemove;
        UPDATE application_approver SET employee_id = empKeep WHERE employee_id = empRemove;
        UPDATE application_hr SET employee_id = empKeep WHERE employee_id = empRemove;
        UPDATE application_signer SET employee_id = empKeep WHERE employee_id = empRemove;
        UPDATE application_recipient SET employee_id = empKeep WHERE employee_id = empRemove;
        UPDATE application_responsible SET employee_id = empKeep WHERE employee_id = empRemove;
        UPDATE client_department SET head_manager_id = empKeep WHERE head_manager_id = empRemove;
        UPDATE document_signer SET employee_id = empKeep WHERE employee_id = empRemove;
        UPDATE document_watcher SET employee_id = empKeep WHERE employee_id = empRemove;
        UPDATE employee SET functional_manager_id = empKeep WHERE functional_manager_id = empRemove;
        UPDATE employee_tag SET employee_id = empKeep WHERE employee_id = empRemove;
        UPDATE normative_act_send_to_signing_employee SET employee_id = empKeep WHERE employee_id = empRemove;
        UPDATE normative_act_send_to_signing_task SET last_paginated_employee_id = empKeep WHERE last_paginated_employee_id = empRemove;
        UPDATE prr_employee_sign_debt SET employee_id = empKeep WHERE employee_id = empRemove;
        UPDATE signing_route_participant SET employee_id = empKeep WHERE employee_id = empRemove;
        UPDATE signing_route_template_participant SET employee_id = empKeep WHERE employee_id = empRemove;
        UPDATE update_watcher_department_ids_on_documents_task SET employee_id = empKeep WHERE employee_id = empRemove;

        -- Проверка на наличие уникальной связки emp_keep + normative_act_id, если таковой нет - присваиваем emp_remove -> emp_keep
        UPDATE normative_act_document SET employee_id = empKeep WHERE employee_id = empRemove AND normative_act_id NOT IN (SELECT normative_act_id
                                                                                                                           FROM temp_lna
                                                                                                                           WHERE employee_id = empKeep);
        -- Если же запись emp_keep + normative_act_id уже есть, то удаляем emp_remove
        DELETE FROM normative_act_document WHERE employee_id = empRemove;

        -- Проверка на наличие ролей у emp_keep в legal_entity_employee_role, если роли нет - присваиваем emp_remove -> emp_keep
        UPDATE legal_entity_employee_role SET employee_id = empKeep WHERE employee_id = empRemove AND employee_role_id NOT IN (SELECT employee_role_id
                                                                                                                               FROM temp_roles
                                                                                                                               WHERE employee_id = empKeep);
        -- Если же роль у emp_keep уже есть, то удаляем emp_remove
        DELETE FROM legal_entity_employee_role WHERE employee_id = empRemove;


        -- Проверка на наличие отпусков у emp_keep в employee_vacation_planning, если отпуска нет - присваиваем emp_remove -> emp_keep
        UPDATE employee_vacation_planning SET employee_id = empKeep WHERE employee_id = empRemove AND planning_year NOT IN (SELECT planning_year
                                                                                                                            FROM temp_vacations
                                                                                                                            WHERE employee_id = empKeep);
        -- Если же отпуск у emp_keep уже есть, то удаляем emp_remove
        DELETE FROM legal_entity_employee_role WHERE employee_id = empRemove;

        -- Удаляем связанные записи в таблицах с доступами и процессом увольнения
        DELETE FROM employee_dismiss_task WHERE employee_id IN (empKeep, empRemove);
        DELETE FROM permitted_application_type WHERE employee_id = empRemove;
        DELETE FROM permitted_client_department WHERE employee_id = empRemove;
        DELETE FROM permitted_document_type WHERE employee_id = empRemove;

        -- Разувольняем emp_keep, если он уволен
        UPDATE employee SET dismissed_date = NULL WHERE id = empKeep;

        --Удаляем emp_remove
        DELETE FROM employee WHERE id = empRemove;
    END LOOP;
END $$;
COMMIT;

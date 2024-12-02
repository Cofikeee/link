WITH tenant AS (SELECT *
                FROM tenant
                WHERE host = 'bronevik.hr-link.ru'),
     tenant_package AS (SELECT *
                        FROM tenant_license_package
                        WHERE tenant_id = (SELECT id FROM tenant)
                          AND disabled_date IS NULL
                        ORDER BY created_date DESC
                        LIMIT 1)

SELECT id AS license_package_id, tenant_id AS tenant_id, package_info, omni_info
FROM tenant_package
         CROSS JOIN (SELECT TO_JSON(t.*) AS package_info
                     FROM (SELECT start_date              "startDate",
                                  end_date                "endDate",
                                  user_count::text          "userCount",
                                  admin_hr_count::text    "adminHrCount",
                                  package_sms_limit::text "packageSmsLimit",
                                  monthly_sms_limit::text "monthlySmsLimit",
                                  version
                           FROM tenant_package) AS t)
AS package_info
         CROSS JOIN (SELECT TO_JSON(t.*) AS omni_info
                     FROM (SELECT tenant.host                                     "Тенант",
                                  CONCAT(start_date::date, ' - ', end_date::date) "Действие лицензии",
                                  user_count::int                                 "Пользователь",
                                  admin_hr_count::int                             "Кадровик",
                                  package_sms_limit::int                          "Пакетный лимит СМС"
                           FROM tenant_package
                           LEFT JOIN tenant ON tenant_package.tenant_id = tenant.id) AS t)
AS omni_info;

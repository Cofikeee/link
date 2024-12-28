	WITH tenant AS (
	    SELECT *
	    FROM tenant
	    WHERE host = 'edo.segezha-group.com'
	),
	tenant_package AS (
	    SELECT *
	    FROM tenant_license_package
	    WHERE tenant_id = (SELECT id FROM tenant)
	      AND disabled_date IS NULL
	    ORDER BY created_date DESC
	    LIMIT 1
	)
	
	SELECT id AS license_package_id, tenant_id AS tenant_id, package_info, omni_info
	FROM tenant_package
	         CROSS JOIN (SELECT TO_JSON(t.*) AS package_info
	                     FROM (SELECT to_char(start_date::timestamptz AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS+00:00') "startDate",
	                                  to_char(end_date::timestamptz AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS+00:00')   "endDate",
	                                  user_count::text        "userCount",
	                                  admin_hr_count::text    "adminHrCount",
	                                  package_sms_limit::text "packageSmsLimit",
	                                  monthly_sms_limit::text "monthlySmsLimit",
	                                  version
	                           FROM tenant_package) AS t)
	AS package_info
	         CROSS JOIN (select E'\n' ||
	         				'Тенант: ' || tenant.host || E'\n' ||
	         				'Срок: ' || CONCAT(to_char(start_date::timestamptz AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS+00:00')::date, 
	         				' - ', to_char(end_date::timestamptz AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS+00:00')::date) || E'\n' ||
	         				'Пользователь: ' || user_count || E'\n' ||
	         				'Кадровик: ' || admin_hr_count || E'\n' ||
	         				'СМС: ' || package_sms_limit ||
	         				E'\n'
	         			from tenant_package
						 	LEFT JOIN tenant ON tenant_package.tenant_id = tenant.id) as omni_info;

WITH
    last_update_time AS (
        SELECT t1.tenant_id, max(t1.created_date) last_timestamp
        FROM tenant_service_version_history t1
        GROUP BY t1.tenant_id
    ),
    tenant_versions AS (
        SELECT l.tenant_id, t.service_version_id, l.last_timestamp
        FROM last_update_time l
        JOIN tenant_service_version_history t ON l.tenant_id = t.tenant_id AND l.last_timestamp = t.created_date
    ),
    onprems_managers AS (
        SELECT id
        FROM manager
        WHERE name ilike '%CLOSED%'
    )

SELECT tenant_id, service_version_id, full_version, t.host, sv.created_date
FROM tenant_versions tv
JOIN service_version sv ON tv.service_version_id = sv.id
JOIN tenant t ON t.id = tv.tenant_id
JOIN onprems_managers om ON t.manager_id = om.id
WHERE full_version < '2.66';

DO
$$
    DECLARE
        credName text := 'login';
        credPass text := 'password';
        dbName text := current_database();      -- Имя БД в которой исполняется запрос
        dbColor text;                           -- Цвет монолита для метадаты
        tenantLicensePackageId uuid;            -- Последний пакет лицензий, где упоминается удаляемый админ
        oldUserId uuid := 'admin_to_remove';    -- Удаляемый админ user_id
        newUserId uuid := 'admin_to_add';       -- Новый админ     user_id
        oldClientUserId uuid;                   -- Удаляемый админ client_user_id
        newClientUserId uuid;                   -- Новый админ     client_user_id
        ownerRoleId uuid;                       -- Роль админа     id

    BEGIN
        SELECT id INTO oldClientUserId FROM ekd_ekd.client_user WHERE user_id = oldUserId;
        SELECT id INTO newClientUserId FROM ekd_ekd.client_user WHERE user_id = newUserId;
        SELECT id INTO ownerRoleId FROM ekd_ekd.user_role;

        INSERT INTO ekd_ekd.client_user_role (client_user_id, user_role_id) VALUES (newClientUserId, ownerRoleId);
        DELETE FROM ekd_ekd.client_user_role WHERE client_user_id = oldClientUserId;

        SELECT instance_name INTO dbColor
        FROM dblink('hostaddr=10.1.1.122 dbname=postgres user=' || credName || ' password=' || credPass,
                    'SELECT instance_name FROM supp.v_tenant_database WHERE datname = ''' || dbName || ''' LIMIT 1'
             ) AS t1(instance_name text);
        dbColor := concat(dbColor, '_ekd_metadata_db');


        PERFORM dblink_connect('conn_metadata', 'hostaddr=10.10.1.160 dbname=' || dbColor || ' user=' || credName || ' password=' || credPass);

        SELECT tenant_license_package_id INTO tenantLicensePackageId
        FROM dblink('conn_metadata',
                    'SELECT tenant_license_package_id FROM license WHERE user_id = ''' || oldUserId || ''' ORDER BY created_date DESC LIMIT 1')
            AS t1(tenant_license_package_id uuid);

        PERFORM dblink_exec('conn_metadata', 'BEGIN;');
        PERFORM dblink_exec('conn_metadata',
                            'INSERT INTO license (id, tenant_license_package_id, user_id, type) VALUES (uuid_generate_v4(), ''' || tenantLicensePackageId || ''', ''' || newUserId || ''', ''ADMIN_OR_HR'');');
        PERFORM dblink_exec('conn_metadata',
                            'UPDATE license SET disabled_date = now() WHERE user_id =  ''' || oldUserId || ''' AND tenant_license_package_id = ''' || tenantLicensePackageId || ''' AND type = ''ADMIN_OR_HR'';');
        PERFORM dblink_exec('conn_metadata', 'COMMIT;');
        PERFORM dblink_disconnect('conn_metadata');

    END
$$;



-- Bloque PL/SQL Anónimo para generación de usuarios y claves
-- Este bloque genera nombres de usuario y claves para todos los empleados
-- según las reglas de negocio establecidas en TRUCK RENTAL

DECLARE
    -- VARIABLES BIND Y %TYPE
    v_fecha_proceso DATE := SYSDATE;  -- Variable bind para fecha de proceso
    v_contador_iteraciones NUMBER := 0;  -- Contador de iteraciones
    v_total_empleados NUMBER := 0;  -- Total de empleados a procesar
    
    -- VARIABLES %TYPE (basadas en la tabla empleado)
    v_id_emp empleado.id_emp%TYPE;
    v_numrun_emp empleado.numrun_emp%TYPE;
    v_dvrun_emp empleado.dvrun_emp%TYPE;
    v_pnombre_emp empleado.pnombre_emp%TYPE;
    v_snombre_emp empleado.snombre_emp%TYPE;
    v_appaterno_emp empleado.appaterno_emp%TYPE;
    v_fecha_nac empleado.fecha_nac%TYPE;
    v_fecha_contrato empleado.fecha_contrato%TYPE;
    v_sueldo_base empleado.sueldo_base%TYPE;
    v_estado_civil empleado.id_estado_civil%TYPE;
    v_nombre_estado_civil estado_civil.nombre_estado_civil%TYPE;
    
    -- VARIABLES PARA CÁLCULOS (AJUSTADAS A LOS TAMAÑOS DE LA TABLA)
    v_usuario VARCHAR2(20);  -- CAMBIADO: de 50 a 20
    v_clave VARCHAR2(20);    -- CAMBIADO: de 50 a 20
    v_anios_trabajando NUMBER;
    v_anno_nacimiento NUMBER;
    v_nombre_completo VARCHAR2(60);  -- CAMBIADO: de 100 a 60
    
    -- CURSOR para procesar empleados
    CURSOR c_empleados IS
        SELECT e.id_emp, e.numrun_emp, e.dvrun_emp, e.pnombre_emp, 
               e.snombre_emp, e.appaterno_emp, e.fecha_nac, 
               e.fecha_contrato, e.sueldo_base, e.id_estado_civil,
               ec.nombre_estado_civil
        FROM empleado e
        JOIN estado_civil ec ON e.id_estado_civil = ec.id_estado_civil
        ORDER BY e.id_emp;
    
BEGIN
    -- 1. TRUNCAR TABLA (Dynamic SQL)
    -- Documentación: Esta sentencia SQL elimina todos los registros de la tabla
    -- USUARIO_CLAVE para permitir múltiples ejecuciones del proceso
    BEGIN
        EXECUTE IMMEDIATE 'TRUNCATE TABLE USUARIO_CLAVE';
        DBMS_OUTPUT.PUT_LINE('Tabla USUARIO_CLAVE truncada exitosamente.');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('NOTA: La tabla USUARIO_CLAVE no existe o no se pudo truncar: ' || SQLERRM);
    END;
    
    -- 2. INICIALIZAR CONTADORES
    SELECT COUNT(*) INTO v_total_empleados FROM empleado;
    
    DBMS_OUTPUT.PUT_LINE('Total de empleados a procesar: ' || v_total_empleados);
    
    -- Verificar que hay empleados para procesar
    IF v_total_empleados = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: No hay empleados para procesar.');
        RETURN;
    END IF;
    
    -- 3. PROCESAR CADA EMPLEADO
    -- Documentación PL/SQL: Esta estructura FOR procesa cada empleado individualmente
    -- utilizando un cursor explícito para mejor control y eficiencia
    FOR emp_rec IN c_empleados LOOP
        v_contador_iteraciones := v_contador_iteraciones + 1;
        
        -- Asignar valores del cursor a variables
        v_id_emp := emp_rec.id_emp;
        v_numrun_emp := emp_rec.numrun_emp;
        v_dvrun_emp := emp_rec.dvrun_emp;
        v_pnombre_emp := emp_rec.pnombre_emp;
        v_snombre_emp := emp_rec.snombre_emp;
        v_appaterno_emp := emp_rec.appaterno_emp;
        v_fecha_nac := emp_rec.fecha_nac;
        v_fecha_contrato := emp_rec.fecha_contrato;
        v_sueldo_base := emp_rec.sueldo_base;
        v_estado_civil := emp_rec.id_estado_civil;
        v_nombre_estado_civil := emp_rec.nombre_estado_civil;
        
        -- Construir nombre completo (limitado a 60 caracteres)
        v_nombre_completo := SUBSTR(
            emp_rec.pnombre_emp || ' ' || 
            NVL(emp_rec.snombre_emp || ' ', '') || 
            emp_rec.appaterno_emp, 1, 60);
        
        -- 4. CÁLCULOS PARA NOMBRE DE USUARIO (limitado a 20 caracteres)
        
        -- a) Primera letra del estado civil en minúscula
        v_usuario := LOWER(SUBSTR(v_nombre_estado_civil, 1, 1));
        
        -- b) Tres primeras letras del primer nombre
        v_usuario := v_usuario || LOWER(SUBSTR(v_pnombre_emp, 1, 3));
        
        -- c) Largo del primer nombre
        v_usuario := v_usuario || LENGTH(v_pnombre_emp);
        
        -- d) Asterisco
        v_usuario := v_usuario || '*';
        
        -- e) Último dígito del sueldo base (redondeado)
        v_usuario := v_usuario || SUBSTR(TO_CHAR(ROUND(v_sueldo_base)), -1);
        
        -- f) Dígito verificador del RUN
        v_usuario := v_usuario || v_dvrun_emp;
        
        -- g) Años trabajando en la empresa (redondeado)
        v_anios_trabajando := ROUND(MONTHS_BETWEEN(v_fecha_proceso, v_fecha_contrato) / 12);
        v_usuario := v_usuario || v_anios_trabajando;
        
        -- h) Agregar 'X' si tiene menos de 10 años
        IF v_anios_trabajando < 10 THEN
            v_usuario := v_usuario || 'X';
        END IF;
        
        -- Asegurar que el usuario no exceda 20 caracteres
        v_usuario := SUBSTR(v_usuario, 1, 20);
        
        -- 5. CÁLCULOS PARA CLAVE (limitado a 20 caracteres)
        
        -- a) Tercer dígito del RUN
        v_clave := SUBSTR(TO_CHAR(v_numrun_emp), 3, 1);
        
        -- b) Año de nacimiento aumentado en 2
        v_anno_nacimiento := EXTRACT(YEAR FROM v_fecha_nac) + 2;
        v_clave := v_clave || v_anno_nacimiento;
        
        -- c) Tres últimos dígitos del sueldo base disminuido en 1 (redondeado)
        v_clave := v_clave || SUBSTR(TO_CHAR(ROUND(v_sueldo_base) - 1), -3);
        
        -- d) Dos letras del apellido paterno según estado civil
        BEGIN
            CASE UPPER(v_nombre_estado_civil)
                WHEN 'CASADO' THEN
                    v_clave := v_clave || LOWER(SUBSTR(v_appaterno_emp, 1, 2));
                WHEN 'ACUERDO DE UNION CIVIL' THEN
                    v_clave := v_clave || LOWER(SUBSTR(v_appaterno_emp, 1, 2));
                WHEN 'SOLTERO' THEN
                    v_clave := v_clave || LOWER(SUBSTR(v_appaterno_emp, 1, 1) || 
                              SUBSTR(v_appaterno_emp, -1));
                WHEN 'DIVORCIADO' THEN
                    v_clave := v_clave || LOWER(SUBSTR(v_appaterno_emp, 1, 1) || 
                              SUBSTR(v_appaterno_emp, -1));
                WHEN 'VIUDO' THEN
                    v_clave := v_clave || LOWER(SUBSTR(v_appaterno_emp, -3, 2));
                WHEN 'SEPARADO' THEN
                    v_clave := v_clave || LOWER(SUBSTR(v_appaterno_emp, -2));
                ELSE
                    v_clave := v_clave || 'xx';  -- Valor por defecto
            END CASE;
        EXCEPTION
            WHEN OTHERS THEN
                v_clave := v_clave || 'xx';  -- En caso de error en el apellido
        END;
        
        -- e) Identificación del empleado
        v_clave := v_clave || v_id_emp;
        
        -- f) Mes y año de la base de datos (en formato numérico: MMYYYY)
        v_clave := v_clave || TO_CHAR(v_fecha_proceso, 'MMYYYY');
        
        -- Asegurar que la clave no exceda 20 caracteres
        v_clave := SUBSTR(v_clave, 1, 20);
        
        -- 6. INSERTAR EN TABLA USUARIO_CLAVE
        BEGIN
            INSERT INTO USUARIO_CLAVE (
                id_emp, numrun_emp, dvrun_emp, nombre_empleado, 
                nombre_usuario, clave_usuario
            ) VALUES (
                v_id_emp, v_numrun_emp, v_dvrun_emp, v_nombre_completo,
                v_usuario, v_clave
            );
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error insertando empleado ID ' || v_id_emp || ': ' || SQLERRM);
                DBMS_OUTPUT.PUT_LINE('Usuario: ' || v_usuario || ' (longitud: ' || LENGTH(v_usuario) || ')');
                DBMS_OUTPUT.PUT_LINE('Clave: ' || v_clave || ' (longitud: ' || LENGTH(v_clave) || ')');
        END;
        
        -- Mostrar progreso cada 5 empleados
        IF MOD(v_contador_iteraciones, 5) = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Procesados ' || v_contador_iteraciones || ' de ' || v_total_empleados || ' empleados...');
        END IF;
        
        -- Mostrar detalles del primer empleado para verificación
        IF v_contador_iteraciones = 1 THEN
            DBMS_OUTPUT.PUT_LINE('--- EJEMPLO PRIMER EMPLEADO ---');
            DBMS_OUTPUT.PUT_LINE('ID: ' || v_id_emp);
            DBMS_OUTPUT.PUT_LINE('Nombre: ' || v_nombre_completo);
            DBMS_OUTPUT.PUT_LINE('Estado Civil: ' || v_nombre_estado_civil);
            DBMS_OUTPUT.PUT_LINE('Usuario: ' || v_usuario || ' (longitud: ' || LENGTH(v_usuario) || ')');
            DBMS_OUTPUT.PUT_LINE('Clave: ' || v_clave || ' (longitud: ' || LENGTH(v_clave) || ')');
            DBMS_OUTPUT.PUT_LINE('------------------------------');
        END IF;
        
    END LOOP;
    
    -- 7. CONFIRMACIÓN DE TRANSACCIONES
    -- Solo se confirma si se procesaron todos los empleados
    IF v_contador_iteraciones = v_total_empleados THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('¡PROCESO COMPLETADO EXITOSAMENTE!');
        DBMS_OUTPUT.PUT_LINE('Total de registros insertados: ' || v_contador_iteraciones);
        DBMS_OUTPUT.PUT_LINE('Fecha de proceso: ' || TO_CHAR(v_fecha_proceso, 'DD/MM/YYYY HH24:MI:SS'));
        
        -- Mostrar resumen final
        DBMS_OUTPUT.PUT_LINE('--- RESUMEN FINAL ---');
        DBMS_OUTPUT.PUT_LINE('Empleados procesados: ' || v_contador_iteraciones);
        DBMS_OUTPUT.PUT_LINE('Transacción confirmada (COMMIT)');
        
        -- Mostrar algunos registros generados
        DBMS_OUTPUT.PUT_LINE('--- MUESTRA DE REGISTROS GENERADOS ---');
        FOR r IN (SELECT * FROM USUARIO_CLAVE WHERE ROWNUM <= 3 ORDER BY id_emp) LOOP
            DBMS_OUTPUT.PUT_LINE('ID: ' || r.id_emp || ' | Usuario: ' || r.nombre_usuario || ' | Clave: ' || r.clave_usuario);
        END LOOP;
        
    ELSE
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR: No se procesaron todos los empleados.');
        DBMS_OUTPUT.PUT_LINE('Procesados: ' || v_contador_iteraciones || ' de ' || v_total_empleados);
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR GLOBAL EN EL PROCESO: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Código de error: ' || SQLCODE);
        DBMS_OUTPUT.PUT_LINE('Empleados procesados antes del error: ' || v_contador_iteraciones);
END;
/
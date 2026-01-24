-- CASO 1: Morosidad para Acreditación
-- Clínica KETEKURA - Procesamiento de pagos atrasados

-- Variable bind para el año de proceso
VAR b_anno_proceso NUMBER;
EXEC :b_anno_proceso := EXTRACT(YEAR FROM SYSDATE) - 1;

DECLARE
    -- 1. VARIABLE TIPO REGISTRO 
    TYPE t_registro_paciente IS RECORD (
        run paciente.pac_run%TYPE,
        dv paciente.dv_run%TYPE,
        pnombre paciente.pnombre%TYPE,
        snombre paciente.snombre%TYPE,
        apaterno paciente.apaterno%TYPE,
        amaterno paciente.amaterno%TYPE,
        fecha_nac paciente.fecha_nacimiento%TYPE
    );
    
    -- 2. VARRAY para multas por especialidad 
    TYPE t_varray_multas IS VARRAY(7) OF NUMBER;
    v_multas t_varray_multas;
    
    -- 3. Variables individuales
    v_registro t_registro_paciente;
    v_ate_id atencion.ate_id%TYPE;
    v_especialidad especialidad.nombre%TYPE;
    v_fecha_venc pago_atencion.fecha_venc_pago%TYPE;
    v_fecha_pago pago_atencion.fecha_pago%TYPE;
    v_dias_morosidad NUMBER(3);
    v_edad NUMBER(3);
    v_multa_diaria NUMBER(6);
    v_multa_total NUMBER(8);
    v_descuento NUMBER(4,2);
    v_multa_final NUMBER(8);
    v_contador NUMBER := 0;
    v_total_multas NUMBER := 0;
    
   -- 4. CURSOR EXPLÍCITO 
-- Un cursor explícito nos permite recorrer los resultados de una consulta SQL
-- Aquí definimos la consulta que traerá los pacientes con pagos atrasados
CURSOR c_pacientes_morosos IS
    SELECT 
        -- Datos del paciente (de la tabla PACIENTE)
        p.pac_run,           -- RUN del paciente 
        p.dv_run,            -- Dígito verificador 
        p.pnombre,           -- Primer nombre
        p.snombre,           -- Segundo nombre (puede ser NULL)
        p.apaterno,          -- Apellido paterno
        p.amaterno,          -- Apellido materno
        p.fecha_nacimiento,  -- Fecha de nacimiento para calcular edad
        
        -- Datos de la atención (de la tabla ATENCION)
        a.ate_id,            -- ID único de la atención médica
        
        -- Datos de la especialidad (de la tabla ESPECIALIDAD)
        esp.nombre,          -- Nombre de la especialidad médica
        
        -- Datos del pago (de la tabla PAGO_ATENCION)
        pa.fecha_venc_pago,  -- Fecha en que venció el pago
        pa.fecha_pago        -- Fecha en que realmente se pagó
    
    -- Tablas que participan en la consulta:
    FROM paciente p                     -- Tabla principal: pacientes
    JOIN atencion a ON p.pac_run = a.pac_run           -- Une pacientes con sus atenciones
    JOIN pago_atencion pa ON a.ate_id = pa.ate_id      -- Une atenciones con sus pagos
    JOIN especialidad esp ON a.esp_id = esp.esp_id     -- Une atenciones con especialidades
    
    -- Condiciones del WHERE (filtros):
    WHERE EXTRACT(YEAR FROM pa.fecha_pago) = :b_anno_proceso  -- Solo pagos del año anterior
      AND pa.fecha_pago > pa.fecha_venc_pago                 -- Solo pagos con morosidad
      
    -- Ordenamiento de resultados:
    ORDER BY p.apaterno, p.pnombre;  -- Orden alfabético por apellido y nombre
    
BEGIN
    -- Inicializar VARRAY (como se vio en clase)
    v_multas := t_varray_multas(1200, 1300, 1700, 1900, 1100, 2000, 2300);
    
    -- Preparar tabla - CORRECCIÓN: Usar EXECUTE IMMEDIATE
    EXECUTE IMMEDIATE 'TRUNCATE TABLE PAGO_MOROSO';
    
    DBMS_OUTPUT.PUT_LINE('PROCESANDO MOROSIDAD - AÑO ' || :b_anno_proceso);
    DBMS_OUTPUT.PUT_LINE('=============================================');
    
    -- 5. USAR CURSOR EXPLÍCITO CON LOOP BÁSICO
    OPEN c_pacientes_morosos;
    
    LOOP
        FETCH c_pacientes_morosos INTO 
            v_registro.run, v_registro.dv, v_registro.pnombre,
            v_registro.snombre, v_registro.apaterno, v_registro.amaterno,
            v_registro.fecha_nac, v_ate_id, v_especialidad,
            v_fecha_venc, v_fecha_pago;
        
        EXIT WHEN c_pacientes_morosos%NOTFOUND;
        
        -- Calcular días de morosidad
        v_dias_morosidad := v_fecha_pago - v_fecha_venc;
        
        IF v_dias_morosidad <= 0 THEN
            CONTINUE;
        END IF;
        
        -- Calcular edad
        v_edad := TRUNC(MONTHS_BETWEEN(v_fecha_pago, v_registro.fecha_nac) / 12);
        
        -- 6. ESTRUCTURA IF-THEN-ELSIF 
        IF v_especialidad IN ('Cirugía General', 'Dermatología') THEN
            v_multa_diaria := v_multas(1);
        ELSIF v_especialidad = 'Ortopedia y Traumatología' THEN
            v_multa_diaria := v_multas(2);
        ELSIF v_especialidad IN ('Inmunología', 'Otorrinolaringología') THEN
            v_multa_diaria := v_multas(3);
        ELSIF v_especialidad IN ('Fisiatría', 'Medicina Interna') THEN
            v_multa_diaria := v_multas(4);
        ELSIF v_especialidad = 'Medicina General' THEN
            v_multa_diaria := v_multas(5);
        ELSIF v_especialidad = 'Psiquiatría Adultos' THEN
            v_multa_diaria := v_multas(6);
        ELSIF v_especialidad IN ('Cirugía Digestiva', 'Reumatología') THEN
            v_multa_diaria := v_multas(7);
        ELSE
            v_multa_diaria := 1000;
        END IF;
        
        -- Calcular el monto total de la multa (sin considerar descuentos aún)
        -- Multiplicamos los días de morosidad por el valor de multa diaria
        v_multa_total := v_dias_morosidad * v_multa_diaria;
        
        -- 7. USAR CASE para descuentos
        v_descuento := 0;
        
        IF v_edad >= 65 THEN
            CASE 
                WHEN v_edad BETWEEN 65 AND 74 THEN
                    v_descuento := 15;
                WHEN v_edad BETWEEN 75 AND 84 THEN
                    v_descuento := 20;
                WHEN v_edad >= 85 THEN
                    v_descuento := 25;
                ELSE
                    v_descuento := 0;
            END CASE;
        END IF;
        
        -- Aplicar descuento
        v_multa_final := v_multa_total - (v_multa_total * v_descuento / 100);
        
        -- Insertar en tabla
        INSERT INTO PAGO_MOROSO (
            pac_run,
            pac_dv_run,
            pac_nombre,
            ate_id,
            fecha_venc_pago,
            fecha_pago,
            dias_morosidad,
            especialidad_atencion,
            monto_multa
        ) VALUES (
            v_registro.run,
            v_registro.dv,
            INITCAP(v_registro.pnombre) || ' ' || 
            INITCAP(v_registro.snombre) || ' ' ||
            INITCAP(v_registro.apaterno) || ' ' ||
            INITCAP(v_registro.amaterno),
            v_ate_id,
            v_fecha_venc,
            v_fecha_pago,
            v_dias_morosidad,
            v_especialidad,
            v_multa_final
        );
        
        v_contador := v_contador + 1;
        v_total_multas := v_total_multas + v_multa_final;
        
        -- 8. WHILE LOOP para mostrar progreso cada 5 registros
        IF MOD(v_contador, 5) = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Procesados: ' || v_contador || ' registros');
        END IF;
        
    END LOOP;
    
    CLOSE c_pacientes_morosos;
    
    -- 9. FOR LOOP para mostrar la tabla final BIEN FORMATEADA
    DBMS_OUTPUT.PUT_LINE(chr(10) || 'TABLA PAGO_MOROSO:');
    DBMS_OUTPUT.PUT_LINE('==========================================================================================================');
    -- Títulos ALINEADOS con los datos
    DBMS_OUTPUT.PUT_LINE(
        RPAD('PAC_RUN', 13) || 
        RPAD('PAC_NOMBRE', 25) || 
        RPAD('ATE_ID', 8) || 
        RPAD('FECHA_VENC', 12) || 
        RPAD('FECHA_PAGO', 12) || 
        RPAD('DIAS', 6) || 
        RPAD('ESPECIALIDAD', 20) || 
        'MONTO_MULTA'
    );
    DBMS_OUTPUT.PUT_LINE('==========================================================================================================');
    
    -- Variable para almacenar línea formateada
    DECLARE
        v_linea VARCHAR2(200);
    BEGIN
        FOR fila IN (SELECT * FROM PAGO_MOROSO ORDER BY pac_nombre) LOOP
            v_linea := 
                RPAD(fila.pac_run || '-' || fila.pac_dv_run, 13) || 
                RPAD(SUBSTR(fila.pac_nombre, 1, 23), 25) || 
                RPAD(fila.ate_id, 8) || 
                RPAD(TO_CHAR(fila.fecha_venc_pago, 'DD/MM/YY'), 12) || 
                RPAD(TO_CHAR(fila.fecha_pago, 'DD/MM/YY'), 12) || 
                RPAD(fila.dias_morosidad, 6) || 
                RPAD(SUBSTR(fila.especialidad_atencion, 1, 18), 20) || 
                '$' || TO_CHAR(fila.monto_multa, '999,999');
            DBMS_OUTPUT.PUT_LINE(v_linea);
        END LOOP;
    END;
    
    DBMS_OUTPUT.PUT_LINE('==========================================================================================================');
    DBMS_OUTPUT.PUT_LINE('Total registros: ' || v_contador);
    DBMS_OUTPUT.PUT_LINE('Total multas: $' || TO_CHAR(v_total_multas, '999,999,999'));
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE(chr(10) || 'Proceso completado exitosamente.');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END;
/























-- CASO 2: Servicio Médico a la Comunidad
-- Clínica KETEKURA - Asignación de médicos a servicios de salud pública

-- Variable bind para el año de proceso
VAR b_anno_proceso NUMBER;
EXEC :b_anno_proceso := EXTRACT(YEAR FROM SYSDATE) - 1;

DECLARE
    -- Variables para datos del médico (usando %TYPE como buena práctica)
    v_run medico.med_run%TYPE;
    v_dv medico.dv_run%TYPE;
    v_nombre_completo VARCHAR2(50);
    v_unidad unidad.nombre%TYPE;
    v_apaterno medico.apaterno%TYPE;
    
    -- Variables para cálculos
    v_total_atenciones NUMBER(3);
    v_max_atenciones NUMBER(3);
    v_correo VARCHAR2(25);
    v_destinacion VARCHAR2(50);
    
    -- Contadores 
    v_medicos_procesados NUMBER := 0;
    v_medicos_insertados NUMBER := 0;
    
    -- Registro PL/SQL para organizar los datos antes de insertar
    TYPE t_registro_medico IS RECORD (
        run_medico VARCHAR2(15),
        nombre_medico VARCHAR2(50),
        unidad VARCHAR2(50),
        correo_institucional VARCHAR2(25),
        total_aten_medicas NUMBER(2),
        destinacion VARCHAR2(50)
    );
    
    v_registro t_registro_medico;
    
    -- VARRAY para las tres posibles destinaciones
    TYPE t_array_dest IS VARRAY(3) OF VARCHAR2(50);
    v_destinaciones t_array_dest;
    
    -- Cursor explícito para TODOS los médicos, ordenado correctamente
    CURSOR c_medicos IS
        SELECT m.med_run, m.dv_run,
               m.pnombre || ' ' || m.snombre || ' ' || m.apaterno || ' ' || m.amaterno as nombre_completo,
               u.nombre as unidad_nombre,
               m.apaterno
        FROM medico m
        JOIN unidad u ON m.uni_id = u.uni_id
        ORDER BY u.nombre, m.apaterno; -- Orden alfabético por unidad y apellido paterno

BEGIN
    -- Inicializar VARRAY 
    v_destinaciones := t_array_dest(
        'Servicio de Atención Primaria de Urgencia (SAPU)',
        'Hospitales del área de la Salud Pública',
        'Centros de Salud Familiar (CESFAM)'
    );
    
    -- 1. PREPARAR LA TABLA 
    EXECUTE IMMEDIATE 'TRUNCATE TABLE MEDICO_SERVICIO_COMUNIDAD';
    DBMS_OUTPUT.PUT_LINE('INICIANDO PROCESO DE ASIGNACIÓN A SERVICIO COMUNITARIO');
    DBMS_OUTPUT.PUT_LINE('Año de referencia: ' || :b_anno_proceso);
    DBMS_OUTPUT.PUT_LINE('====================================================');
    
    -- 2. ENCONTRAR EL MÁXIMO DE ATENCIONES (Usa la variable bind)
    SELECT NVL(MAX(cnt), 0) INTO v_max_atenciones
    FROM (
        SELECT COUNT(*) as cnt
        FROM atencion
        WHERE EXTRACT(YEAR FROM fecha_atencion) = :b_anno_proceso
        GROUP BY med_run
    );
    
    DBMS_OUTPUT.PUT_LINE('Máximo de atenciones médicas en ' || :b_anno_proceso || ': ' || v_max_atenciones);
    
    IF v_max_atenciones = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ADVERTENCIA: No hay atenciones registradas para el año ' || :b_anno_proceso);
    END IF;
    
    -- 3. PROCESAR CADA MÉDICO (Bucle con cursor explícito)
    OPEN c_medicos;
    
    LOOP
        FETCH c_medicos INTO v_run, v_dv, v_nombre_completo, v_unidad, v_apaterno;
        EXIT WHEN c_medicos%NOTFOUND;
        
        v_medicos_procesados := v_medicos_procesados + 1;
        
        -- Contar atenciones de este médico en el año
        BEGIN
            SELECT COUNT(*)
            INTO v_total_atenciones
            FROM atencion
            WHERE med_run = v_run
              AND EXTRACT(YEAR FROM fecha_atencion) = :b_anno_proceso;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_total_atenciones := 0;
        END;
        
        -- Verificar si es candidato (realizó menos del máximo)
        IF v_total_atenciones < v_max_atenciones THEN
            
            -- Generar correo institucional (Fórmula exacta del caso)
            -- 1. Dos primeras letras de la unidad (mayúsculas, sin espacios)
            v_correo := UPPER(SUBSTR(TRIM(v_unidad), 1, 2));
            
            -- 2. Penúltima y antepenúltima letra del apellido paterno
            IF LENGTH(v_apaterno) >= 3 THEN
                v_correo := v_correo || 
                           UPPER(SUBSTR(v_apaterno, LENGTH(v_apaterno)-2, 1)) ||
                           UPPER(SUBSTR(v_apaterno, LENGTH(v_apaterno)-1, 1));
            ELSIF LENGTH(v_apaterno) = 2 THEN
                v_correo := v_correo || UPPER(v_apaterno);
            ELSE
                v_correo := v_correo || UPPER(v_apaterno) || 'X';
            END IF;
            
            -- 3. Tres últimos dígitos del RUN
            v_correo := v_correo || SUBSTR(TO_CHAR(v_run), -3);
            
            -- 4. Dominio (en minúsculas)
            v_correo := LOWER(v_correo) || '@ketekura.cl';
            
            -- 5. Asegurar que no exceda el tamaño de la columna (25 caracteres)
            IF LENGTH(v_correo) > 25 THEN
                v_correo := SUBSTR(v_correo, 1, 25);
            END IF;
            
            -- DETERMINAR DESTINACIÓN SEGÚN TABLA
            -- Normalizar el nombre de la unidad para comparación
            v_unidad := UPPER(v_unidad);
            
            -- Tabla completa:
            -- Atención Adulto y Atención Ambulatoria: Cualquiera -> SAPU
            IF v_unidad LIKE '%ADULTO%' OR v_unidad LIKE '%AMBULATORIA%' THEN
                v_destinacion := v_destinaciones(1); -- SAPU
            
            -- Atención Urgencia: 0-3 -> SAPU, Más de 3 -> Hospitales
            ELSIF v_unidad LIKE '%URGENCIA%' THEN
                IF v_total_atenciones BETWEEN 0 AND 3 THEN
                    v_destinacion := v_destinaciones(1); -- SAPU
                ELSE
                    v_destinacion := v_destinaciones(2); -- Hospitales
                END IF;
            
            -- Cardiología y Oncología: Cualquiera -> Hospitales
            ELSIF v_unidad LIKE '%CARDIOLOGÍA%' OR v_unidad LIKE '%ONCOLÓGICA%' THEN
                v_destinacion := v_destinaciones(2); -- Hospitales
            
            -- Cirugía y Cirugía Plástica: 0-3 -> SAPU, Más de 3 -> Hospitales
            ELSIF v_unidad LIKE '%CIRUGÍA%' THEN
                IF v_total_atenciones BETWEEN 0 AND 3 THEN
                    v_destinacion := v_destinaciones(1); -- SAPU
                ELSE
                    v_destinacion := v_destinaciones(2); -- Hospitales
                END IF;
            
            -- Paciente Crítico: Cualquiera -> Hospitales
            ELSIF v_unidad LIKE '%CRÍTICO%' THEN
                v_destinacion := v_destinaciones(2); -- Hospitales
            
            -- Psiquiatría y Salud Mental: Cualquiera -> CESFAM
            ELSIF v_unidad LIKE '%PSIQUIATRÍA%' OR v_unidad LIKE '%SALUD MENTAL%' THEN
                v_destinacion := v_destinaciones(3); -- CESFAM
            
            -- Traumatología Adulto: 0-3 -> SAPU, Más de 3 -> Hospitales
            ELSIF v_unidad LIKE '%TRAUMATOLOGÍA%' THEN
                IF v_total_atenciones BETWEEN 0 AND 3 THEN
                    v_destinacion := v_destinaciones(1); -- SAPU
                ELSE
                    v_destinacion := v_destinaciones(2); -- Hospitales
                END IF;
            
            -- Para cualquier otra unidad no especificada en Tabla 2
            ELSE
                v_destinacion := 'Por determinar - Unidad no reconocida';
            END IF;
            
            -- Llenar el registro PL/SQL
            v_registro.run_medico := TO_CHAR(v_run) || '-' || v_dv;
            v_registro.nombre_medico := v_nombre_completo;
            v_registro.unidad := v_unidad;
            v_registro.correo_institucional := v_correo;
            v_registro.total_aten_medicas := v_total_atenciones;
            v_registro.destinacion := v_destinacion;
            
            -- Insertar usando los datos del registro
            INSERT INTO MEDICO_SERVICIO_COMUNIDAD (
                unidad, run_medico, nombre_medico, 
                correo_institucional, total_aten_medicas, destinacion
            ) VALUES (
                v_registro.unidad, v_registro.run_medico, v_registro.nombre_medico,
                v_registro.correo_institucional, v_registro.total_aten_medicas, 
                v_registro.destinacion
            );
            
            v_medicos_insertados := v_medicos_insertados + 1;
            
            -- Mostrar progreso cada 10 registros
            IF MOD(v_medicos_insertados, 10) = 0 THEN
                DBMS_OUTPUT.PUT_LINE('  -> Procesados: ' || v_medicos_insertados || ' médicos seleccionados');
            END IF;
            
        END IF; -- Fin del IF que verifica candidatos
        
    END LOOP; -- Fin del bucle principal
    
    CLOSE c_medicos;
    
    -- 4. MOSTRAR RESULTADOS Y CONFIRMAR
    DBMS_OUTPUT.PUT_LINE('====================================================');
    DBMS_OUTPUT.PUT_LINE('PROCESO COMPLETADO EXITOSAMENTE');
    DBMS_OUTPUT.PUT_LINE('====================================================');
    DBMS_OUTPUT.PUT_LINE('RESUMEN:');
    DBMS_OUTPUT.PUT_LINE('  • Total de médicos procesados: ' || v_medicos_procesados);
    DBMS_OUTPUT.PUT_LINE('  • Médicos seleccionados para servicio comunitario: ' || v_medicos_insertados);
    DBMS_OUTPUT.PUT_LINE('  • Criterio: menos de ' || v_max_atenciones || ' atenciones médicas');
    DBMS_OUTPUT.PUT_LINE('  • Año evaluado: ' || :b_anno_proceso);
    
    -- Mostrar distribución por destinación
    DBMS_OUTPUT.PUT_LINE('====================================================');
    DBMS_OUTPUT.PUT_LINE('DISTRIBUCIÓN POR TIPO DE DESTINACIÓN:');
    
    FOR rec IN (
        SELECT destinacion, COUNT(*) as cantidad
        FROM MEDICO_SERVICIO_COMUNIDAD
        GROUP BY destinacion
        ORDER BY cantidad DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  • ' || rec.destinacion || ': ' || rec.cantidad || ' médicos');
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('====================================================');
    
    -- 5. MOSTRAR LA TABLA FORMATEADA CON DBMS_OUTPUT
    DBMS_OUTPUT.PUT_LINE(chr(10) || 'TABLA MEDICO_SERVICIO_COMUNIDAD:');
    DBMS_OUTPUT.PUT_LINE('==================================================================================================================================');
    
    -- Mostrar encabezados
    DBMS_OUTPUT.PUT_LINE(
        RPAD('UNIDAD', 25) || ' ' ||
        RPAD('RUN_MEDICO', 15) || ' ' ||
        RPAD('NOMBRE_MEDICO', 35) || ' ' ||
        RPAD('CORREO', 25) || ' ' ||
        RPAD('ATENC.', 8) || ' ' ||
        'DESTINACION'
    );
    
    DBMS_OUTPUT.PUT_LINE('==================================================================================================================================');
    
    -- Mostrar datos usando FOR LOOP
    FOR fila IN (
        SELECT 
            unidad,
            run_medico,
            nombre_medico,
            correo_institucional,
            total_aten_medicas,
            destinacion
        FROM MEDICO_SERVICIO_COMUNIDAD
        ORDER BY unidad, run_medico
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(SUBSTR(fila.unidad, 1, 24), 25) || ' ' ||
            RPAD(fila.run_medico, 15) || ' ' ||
            RPAD(SUBSTR(fila.nombre_medico, 1, 34), 35) || ' ' ||
            RPAD(SUBSTR(fila.correo_institucional, 1, 24), 25) || ' ' ||
            RPAD(TO_CHAR(fila.total_aten_medicas), 8) || ' ' ||
            SUBSTR(fila.destinacion, 1, 30) || 
            CASE WHEN LENGTH(fila.destinacion) > 30 THEN '...' ELSE '' END
        );
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('==================================================================================================================================');
    DBMS_OUTPUT.PUT_LINE('Total de registros: ' || v_medicos_insertados);
    
    COMMIT; -- Confirmar todos los cambios
    DBMS_OUTPUT.PUT_LINE(chr(10) || 'Transacción confirmada (COMMIT). Datos guardados.');
    
EXCEPTION
    -- Manejo de excepciones con ROLLBACK
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: No se encontraron datos para procesar.');
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Transacción revertida (ROLLBACK).');
        
    WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Se encontraron múltiples registros inesperados.');
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' Transacción revertida (ROLLBACK).');
        
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(' ERROR durante el proceso: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Código de error: ' || SQLCODE);
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' Transacción revertida (ROLLBACK).');
        RAISE;
END;
/

-- Verificación final simple
SELECT 'Proceso completado. ' || COUNT(*) || ' registros en MEDICO_SERVICIO_COMUNIDAD.' 
FROM MEDICO_SERVICIO_COMUNIDAD;
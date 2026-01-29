-- Caso 1: Sistema de Puntos de Tarjeta CATB
-- Uso de Cursor Explícito para procesar transacciones


DECLARE
    -- 1. DECLARACIÓN DE VARIABLES Y TIPOS
    v_anio_ejecucion NUMBER := EXTRACT(YEAR FROM SYSDATE);
    v_puntos NUMBER;
    
    -- VARRAY para valores de puntos (requerimiento 10)
    -- CORRECCIÓN: Los índices en VARRAY empiezan en 1, no en 0
    TYPE t_valores_puntos IS VARRAY(4) OF NUMBER;
    v_valores_puntos t_valores_puntos := t_valores_puntos(250, 300, 550, 700);
    
    -- Variables para el cursor
    v_numrun CLIENTE.numrun%TYPE;
    v_dvrun CLIENTE.dvrun%TYPE;
    v_nro_tarjeta TARJETA_CLIENTE.nro_tarjeta%TYPE;
    v_nro_transaccion TRANSACCION_TARJETA_CLIENTE.nro_transaccion%TYPE;
    v_fecha_transaccion TRANSACCION_TARJETA_CLIENTE.fecha_transaccion%TYPE;
    v_tipo_transaccion TIPO_TRANSACCION_TARJETA.nombre_tptran_tarjeta%TYPE;
    v_monto_transaccion TRANSACCION_TARJETA_CLIENTE.monto_transaccion%TYPE;
    
    -- Variables para acumulación mensual
    v_mes_anno VARCHAR2(6);
    v_mes_actual VARCHAR2(2);
    v_anno_actual VARCHAR2(4);
    v_total_compras NUMBER := 0;
    v_total_puntos_compras NUMBER := 0;
    v_total_avances NUMBER := 0;
    v_total_puntos_avances NUMBER := 0;
    v_total_savances NUMBER := 0;
    v_total_puntos_savances NUMBER := 0;
    v_mes_anterior VARCHAR2(6) := NULL;
    
    -- Parámetros para tramos de montos 
    v_tramo1_inf NUMBER := 20000;
    v_tramo1_sup NUMBER := 50000;
    v_tramo2_inf NUMBER := 50001;
    v_tramo2_sup NUMBER := 100000;
    v_tramo3_inf NUMBER := 100001;

    
    -- 2. DECLARACIÓN DEL CURSOR EXPLÍCITO
    CURSOR c_transacciones IS
        SELECT 
            c.numrun,
            c.dvrun,
            ttc.nro_tarjeta,
            ttc.nro_transaccion,
            ttc.fecha_transaccion,
            ttt.nombre_tptran_tarjeta AS tipo_transaccion,
            ttc.monto_transaccion

        FROM CLIENTE c
        JOIN TARJETA_CLIENTE tc ON c.numrun = tc.numrun
        JOIN TRANSACCION_TARJETA_CLIENTE ttc ON tc.nro_tarjeta = ttc.nro_tarjeta
        JOIN TIPO_TRANSACCION_TARJETA ttt ON ttc.cod_tptran_tarjeta = ttt.cod_tptran_tarjeta

        -- Buscar transacciones del año actual para pruebas
        -- Cambiar por v_anio_ejecucion - 1 si se requiere del año anterior
        WHERE EXTRACT(YEAR FROM ttc.fecha_transaccion) = v_anio_ejecucion
        ORDER BY 
            TO_CHAR(ttc.fecha_transaccion, 'MM'),
            TO_CHAR(ttc.fecha_transaccion, 'YYYY'),
            ttc.fecha_transaccion,
            c.numrun,
            ttc.nro_transaccion;
    
BEGIN
    -- 3. TRUNCAR TABLAS (requerimiento 8)
    DBMS_OUTPUT.PUT_LINE('Iniciando proceso de cálculo de puntos...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE DETALLE_PUNTOS_TARJETA_CATB';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE RESUMEN_PUNTOS_TARJETA_CATB';
    
    -- 4. ABRIR EL CURSOR
    DBMS_OUTPUT.PUT_LINE('Abriendo cursor de transacciones...');
    OPEN c_transacciones;
    
    -- 5. MANEJAR EL CURSOR CON LOOP
    DBMS_OUTPUT.PUT_LINE('Procesando transacciones...');
    LOOP
        -- FETCH: obtener una fila del cursor
        FETCH c_transacciones INTO 
            v_numrun, 
            v_dvrun, 
            v_nro_tarjeta, 
            v_nro_transaccion, 
            v_fecha_transaccion, 
            v_tipo_transaccion, 
            v_monto_transaccion;
        
        -- Salir del loop cuando no hay más filas
        EXIT WHEN c_transacciones%NOTFOUND;
        
        -- Procesar la fila actual
        v_mes_actual := TO_CHAR(v_fecha_transaccion, 'MM');
        v_anno_actual := TO_CHAR(v_fecha_transaccion, 'YYYY');
        v_mes_anno := v_mes_actual || v_anno_actual;
        
        -- Manejar cambio de mes
        IF v_mes_anterior IS NOT NULL AND v_mes_anno != v_mes_anterior THEN
            INSERT INTO RESUMEN_PUNTOS_TARJETA_CATB VALUES (
                v_mes_anterior,
                v_total_compras,
                v_total_puntos_compras,
                v_total_avances,
                v_total_puntos_avances,
                v_total_savances,
                v_total_puntos_savances
            );
            
            -- Reiniciar contadores
            v_total_compras := 0;
            v_total_puntos_compras := 0;
            v_total_avances := 0;
            v_total_puntos_avances := 0;
            v_total_savances := 0;
            v_total_puntos_savances := 0;
        END IF;
        
        -- Calcular puntos (requerimiento 12)
        -- CORRECCIÓN: Lógica de puntos corregida
        v_puntos := 0;
        
        IF v_tipo_transaccion = 'Compras Tiendas Retail o Asociadas' THEN

            -- Para compras: puntos según tramos de monto
            IF v_monto_transaccion BETWEEN v_tramo1_inf AND v_tramo1_sup THEN
                v_puntos := v_valores_puntos(2);  -- 300 (índice 2 del VARRAY)
            ELSIF v_monto_transaccion BETWEEN v_tramo2_inf AND v_tramo2_sup THEN
                v_puntos := v_valores_puntos(3);  -- 550 (índice 3 del VARRAY)
            ELSIF v_monto_transaccion >= v_tramo3_inf THEN
                v_puntos := v_valores_puntos(4);  -- 700 (índice 4 del VARRAY)
            ELSE
                v_puntos := v_valores_puntos(1);  -- 250 (índice 1 del VARRAY)
            END IF;
            
            v_total_compras := v_total_compras + v_monto_transaccion;
            v_total_puntos_compras := v_total_puntos_compras + v_puntos;
            
        ELSIF v_tipo_transaccion = 'Avance en Efectivo' THEN
            -- Para avances: siempre 250 puntos
            v_puntos := v_valores_puntos(1);  -- 250 puntos (índice 1)
            v_total_avances := v_total_avances + v_monto_transaccion;
            v_total_puntos_avances := v_total_puntos_avances + v_puntos;
            
        ELSIF v_tipo_transaccion = 'Súper Avance en Efectivo' THEN
            -- CORRECCIÓN: Para súper avances también 250 puntos
            v_puntos := v_valores_puntos(1);  -- 250 puntos (índice 1)
            v_total_savances := v_total_savances + v_monto_transaccion;
            v_total_puntos_savances := v_total_puntos_savances + v_puntos;
        END IF;
        
        -- Insertar en detalle
        INSERT INTO DETALLE_PUNTOS_TARJETA_CATB VALUES (
            v_numrun,
            v_dvrun,
            v_nro_tarjeta,
            v_nro_transaccion,
            v_fecha_transaccion,
            v_tipo_transaccion,
            v_monto_transaccion,
            v_puntos
        );
        
        v_mes_anterior := v_mes_anno;
    END LOOP;
    
    -- Insertar último mes
    IF v_mes_anterior IS NOT NULL THEN
        INSERT INTO RESUMEN_PUNTOS_TARJETA_CATB VALUES (
            v_mes_anterior,
            v_total_compras,
            v_total_puntos_compras,
            v_total_avances,
            v_total_puntos_avances,
            v_total_savances,
            v_total_puntos_savances
        );
    END IF;
    
    -- 6. CERRAR EL CURSOR
    CLOSE c_transacciones;
    DBMS_OUTPUT.PUT_LINE('Cursor cerrado.');
    
    -- 7. CONFIRMAR CAMBIOS
    COMMIT;
    
    -- 8. MOSTRAR TABLAS EN FORMATO CORRECTO
    
    -- Primero mostrar tabla DETALLE_PUNTOS_TARJETA_CATB
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '========================================================================================================================================');
    DBMS_OUTPUT.PUT_LINE('TABLA DETALLE_PUNTOS_TARJETA_CATB');
    DBMS_OUTPUT.PUT_LINE('========================================================================================================================================');
    
    -- Encabezados
    DBMS_OUTPUT.PUT_LINE(
        RPAD('NUMRUN', 12) || ' ' ||
        RPAD('DVRUN', 6) || ' ' ||
        RPAD('NRO_TARJETA', 15) || ' ' ||
        RPAD('NRO_TRANSACCION', 15) || ' ' ||
        RPAD('FECHA_TRANSACCION', 18) || ' ' ||
        RPAD('TIPO_TRANSACCION', 40) || ' ' ||
        RPAD('MONTO_TRANSACCION', 18) || ' ' ||
        'PUNTOS_ALLTHEBEST'
    );
    
    -- Línea separadora
    DBMS_OUTPUT.PUT_LINE(
        RPAD('-', 12, '-') || ' ' ||
        RPAD('-', 6, '-') || ' ' ||
        RPAD('-', 15, '-') || ' ' ||
        RPAD('-', 15, '-') || ' ' ||
        RPAD('-', 18, '-') || ' ' ||
        RPAD('-', 40, '-') || ' ' ||
        RPAD('-', 18, '-') || ' ' ||
        '------------------'
    );
    
    -- Datos de la tabla DETALLE
    FOR rec IN (
        SELECT 
            numrun,
            dvrun,
            nro_tarjeta,
            nro_transaccion,
            fecha_transaccion,
            tipo_transaccion,
            monto_transaccion,
            puntos_allthebest
        FROM DETALLE_PUNTOS_TARJETA_CATB 
        ORDER BY fecha_transaccion, numrun, nro_transaccion
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(rec.numrun, 12) || ' ' ||
            RPAD(rec.dvrun, 6) || ' ' ||
            RPAD(rec.nro_tarjeta, 15) || ' ' ||
            RPAD(rec.nro_transaccion, 15) || ' ' ||
            RPAD(TO_CHAR(rec.fecha_transaccion, 'DD/MM/YYYY'), 18) || ' ' ||
            RPAD(rec.tipo_transaccion, 40) || ' ' ||
            RPAD(TO_CHAR(rec.monto_transaccion, '$999G999G999'), 18) || ' ' ||
            rec.puntos_allthebest
        );
    END LOOP;
    
    -- Espacio entre tablas
    DBMS_OUTPUT.PUT_LINE(CHR(10));
    
    -- Mostrar tabla RESUMEN_PUNTOS_TARJETA_CATB
    DBMS_OUTPUT.PUT_LINE('======================================================================================================================================================');
    DBMS_OUTPUT.PUT_LINE('TABLA RESUMEN_PUNTOS_TARJETA_CATB');
    DBMS_OUTPUT.PUT_LINE('======================================================================================================================================================');
    
    -- Encabezados
    DBMS_OUTPUT.PUT_LINE(
        RPAD('MES_ANNO', 10) || ' ' ||
        RPAD('MONTO_TOTAL_COMPRAS', 20) || ' ' ||
        RPAD('TOTAL_PUNTOS_COMPRAS', 20) || ' ' ||
        RPAD('MONTO_TOTAL_AVANCES', 20) || ' ' ||
        RPAD('TOTAL_PUNTOS_AVANCES', 20) || ' ' ||
        RPAD('MONTO_TOTAL_SAVANCES', 20) || ' ' ||
        'TOTAL_PUNTOS_SAVANCES'
    );
    
    -- Línea separadora
    DBMS_OUTPUT.PUT_LINE(
        RPAD('-', 10, '-') || ' ' ||
        RPAD('-', 20, '-') || ' ' ||
        RPAD('-', 20, '-') || ' ' ||
        RPAD('-', 20, '-') || ' ' ||
        RPAD('-', 20, '-') || ' ' ||
        RPAD('-', 20, '-') || ' ' ||
        '---------------------'
    );
    
    -- Datos de la tabla RESUMEN
    FOR rec IN (
        SELECT 
            mes_anno,
            monto_total_compras,
            total_puntos_compras,
            monto_total_avances,
            total_puntos_avances,
            monto_total_savances,
            total_puntos_savances
        FROM RESUMEN_PUNTOS_TARJETA_CATB 
        ORDER BY mes_anno
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(rec.mes_anno, 10) || ' ' ||
            RPAD(TO_CHAR(rec.monto_total_compras, '$999G999G999'), 20) || ' ' ||
            RPAD(rec.total_puntos_compras, 20) || ' ' ||
            RPAD(TO_CHAR(rec.monto_total_avances, '$999G999G999'), 20) || ' ' ||
            RPAD(rec.total_puntos_avances, 20) || ' ' ||
            RPAD(TO_CHAR(rec.monto_total_savances, '$999G999G999'), 20) || ' ' ||
            rec.total_puntos_savances
        );
    END LOOP;
    
    -- Mostrar resumen final
    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Proceso completado exitosamente.');
    
    -- Conteo de registros
    DECLARE
        v_count_detalle NUMBER;
        v_count_resumen NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count_detalle FROM DETALLE_PUNTOS_TARJETA_CATB;
        SELECT COUNT(*) INTO v_count_resumen FROM RESUMEN_PUNTOS_TARJETA_CATB;
        
        DBMS_OUTPUT.PUT_LINE('Registros insertados en DETALLE: ' || v_count_detalle);
        DBMS_OUTPUT.PUT_LINE('Registros insertados en RESUMEN: ' || v_count_resumen);
    END;
    
EXCEPTION
    WHEN OTHERS THEN
        IF c_transacciones%ISOPEN THEN
            CLOSE c_transacciones;
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END;
/














-- Caso 2: Aportes SBIF con cursores explícitos
-- Incluye cursor con parámetro

DECLARE
    -- Variables generales
    v_anio_ejecucion NUMBER := EXTRACT(YEAR FROM SYSDATE);
    v_aporte NUMBER;
    v_porcentaje_aporte NUMBER;
    
    -- Variables para el cursor de detalle
    v_numrun CLIENTE.numrun%TYPE;
    v_dvrun CLIENTE.dvrun%TYPE;
    v_nro_tarjeta TARJETA_CLIENTE.nro_tarjeta%TYPE;
    v_nro_transaccion TRANSACCION_TARJETA_CLIENTE.nro_transaccion%TYPE;
    v_fecha_transaccion DATE;
    v_tipo_transaccion TIPO_TRANSACCION_TARJETA.nombre_tptran_tarjeta%TYPE;
    v_monto_total TRANSACCION_TARJETA_CLIENTE.monto_total_transaccion%TYPE;
    
    -- Variables para el cursor de resumen
    v_mes_anno VARCHAR2(6);
    v_tipo_trans_res VARCHAR2(40);
    v_monto_total_res NUMBER;
    v_aporte_total_res NUMBER;
    
    -- Cursores explícitos (requerimiento 3)
    -- Cursor para avances (con parámetro para el tipo de transacción)
    CURSOR c_avances_detalle (p_tipo_transaccion VARCHAR2) IS
        SELECT 
            c.numrun,
            c.dvrun,
            ttc.nro_tarjeta,
            ttc.nro_transaccion,
            ttc.fecha_transaccion,
            ttt.nombre_tptran_tarjeta AS tipo_transaccion,
            ttc.monto_total_transaccion AS monto_transaccion
        FROM CLIENTE c
        JOIN TARJETA_CLIENTE tc ON c.numrun = tc.numrun
        JOIN TRANSACCION_TARJETA_CLIENTE ttc ON tc.nro_tarjeta = ttc.nro_tarjeta
        JOIN TIPO_TRANSACCION_TARJETA ttt ON ttc.cod_tptran_tarjeta = ttt.cod_tptran_tarjeta
        WHERE ttt.nombre_tptran_tarjeta = p_tipo_transaccion
          AND EXTRACT(YEAR FROM ttc.fecha_transaccion) = v_anio_ejecucion
        ORDER BY 
            ttc.fecha_transaccion,
            c.numrun;
    
    -- Cursor para resumen (sin parámetro)
    CURSOR c_resumen IS
        SELECT 
            TO_CHAR(ttc.fecha_transaccion, 'MMYYYY') AS mes_anno,
            ttt.nombre_tptran_tarjeta AS tipo_transaccion,
            SUM(ttc.monto_total_transaccion) AS monto_total
        FROM TRANSACCION_TARJETA_CLIENTE ttc
        JOIN TIPO_TRANSACCION_TARJETA ttt ON ttc.cod_tptran_tarjeta = ttt.cod_tptran_tarjeta
        WHERE ttt.nombre_tptran_tarjeta IN ('Avance en Efectivo', 'Súper Avance en Efectivo')
          AND EXTRACT(YEAR FROM ttc.fecha_transaccion) = v_anio_ejecucion
        GROUP BY 
            TO_CHAR(ttc.fecha_transaccion, 'MMYYYY'),
            ttt.nombre_tptran_tarjeta
        ORDER BY 
            TO_CHAR(ttc.fecha_transaccion, 'MMYYYY'),
            ttt.nombre_tptran_tarjeta;
    
BEGIN
    -- TRUNCAR las tablas (requerimiento 7)
    EXECUTE IMMEDIATE 'TRUNCATE TABLE DETALLE_APORTE_SBIF';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE RESUMEN_APORTE_SBIF';
    
    DBMS_OUTPUT.PUT_LINE('Iniciando proceso de aportes SBIF...');
    
    -- Procesar AVANCES EN EFECTIVO
    DBMS_OUTPUT.PUT_LINE('Procesando Avances en Efectivo...');
    OPEN c_avances_detalle('Avance en Efectivo');
    LOOP
        FETCH c_avances_detalle INTO 
            v_numrun, 
            v_dvrun, 
            v_nro_tarjeta, 
            v_nro_transaccion, 
            v_fecha_transaccion, 
            v_tipo_transaccion, 
            v_monto_total;
        EXIT WHEN c_avances_detalle%NOTFOUND;
        
        -- Calcular aporte según tramo (requerimiento 8)
        v_aporte := 0;
        v_porcentaje_aporte := 0;
        
        -- Determinar porcentaje según tramo
        BEGIN
            SELECT porc_aporte_sbif INTO v_porcentaje_aporte
            FROM TRAMO_APORTE_SBIF
            WHERE v_monto_total BETWEEN tramo_inf_av_sav AND tramo_sup_av_sav;
            
            -- Calcular aporte
            v_aporte := ROUND(v_monto_total * v_porcentaje_aporte / 100);
            
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Si no encuentra tramo, usar el último (mayor a 600,001)
                SELECT porc_aporte_sbif INTO v_porcentaje_aporte
                FROM TRAMO_APORTE_SBIF
                WHERE tramo_inf_av_sav = 600001;
                
                v_aporte := ROUND(v_monto_total * v_porcentaje_aporte / 100);
        END;
        
        -- Insertar en detalle
        INSERT INTO DETALLE_APORTE_SBIF VALUES (
            v_numrun,
            v_dvrun,
            v_nro_tarjeta,
            v_nro_transaccion,
            v_fecha_transaccion,
            v_tipo_transaccion,
            v_monto_total,
            v_aporte
        );
        
    END LOOP;
    CLOSE c_avances_detalle;
    
    -- Procesar SÚPER AVANCES
    DBMS_OUTPUT.PUT_LINE('Procesando Súper Avances en Efectivo...');
    OPEN c_avances_detalle('Súper Avance en Efectivo');
    LOOP
        FETCH c_avances_detalle INTO 
            v_numrun, 
            v_dvrun, 
            v_nro_tarjeta, 
            v_nro_transaccion, 
            v_fecha_transaccion, 
            v_tipo_transaccion, 
            v_monto_total;
        EXIT WHEN c_avances_detalle%NOTFOUND;
        
        -- Calcular aporte según tramo
        v_aporte := 0;
        v_porcentaje_aporte := 0;
        
        BEGIN
            SELECT porc_aporte_sbif INTO v_porcentaje_aporte
            FROM TRAMO_APORTE_SBIF
            WHERE v_monto_total BETWEEN tramo_inf_av_sav AND tramo_sup_av_sav;
            
            v_aporte := ROUND(v_monto_total * v_porcentaje_aporte / 100);
            
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                SELECT porc_aporte_sbif INTO v_porcentaje_aporte
                FROM TRAMO_APORTE_SBIF
                WHERE tramo_inf_av_sav = 600001;
                
                v_aporte := ROUND(v_monto_total * v_porcentaje_aporte / 100);
        END;
        
        -- Insertar en detalle
        INSERT INTO DETALLE_APORTE_SBIF VALUES (
            v_numrun,
            v_dvrun,
            v_nro_tarjeta,
            v_nro_transaccion,
            v_fecha_transaccion,
            v_tipo_transaccion,
            v_monto_total,
            v_aporte
        );
        
    END LOOP;
    CLOSE c_avances_detalle;
    
    -- Procesar resumen mensual
    DBMS_OUTPUT.PUT_LINE('Generando resumen mensual...');
    OPEN c_resumen;
    LOOP
        FETCH c_resumen INTO v_mes_anno, v_tipo_trans_res, v_monto_total_res;
        EXIT WHEN c_resumen%NOTFOUND;
        
        -- Calcular aporte total para este mes y tipo
        v_aporte_total_res := 0;
        
        -- Obtener todos los detalles de este mes y tipo y sumar los aportes
        FOR rec IN (
            SELECT das.aporte_sbif
            FROM DETALLE_APORTE_SBIF das
            WHERE TO_CHAR(das.fecha_transaccion, 'MMYYYY') = v_mes_anno
              AND das.tipo_transaccion = v_tipo_trans_res
        ) LOOP
            v_aporte_total_res := v_aporte_total_res + rec.aporte_sbif;
        END LOOP;
        
        -- Insertar resumen
        INSERT INTO RESUMEN_APORTE_SBIF VALUES (
            v_mes_anno,
            v_tipo_trans_res,
            v_monto_total_res,
            v_aporte_total_res
        );
        
    END LOOP;
    CLOSE c_resumen;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Proceso de aportes SBIF completado exitosamente.');
    
    -- MOSTRAR TABLAS DESPUÉS DEL COMMIT
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '==============================================================================');
    DBMS_OUTPUT.PUT_LINE('1. CONTENIDO DE LAS TABLAS');
    DBMS_OUTPUT.PUT_LINE('==============================================================================');
    
    -- Mostrar DETALLE_APORTE_SBIF
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== DETALLE_APORTE_SBIF ===');
    
    -- Encabezado de la tabla
    DBMS_OUTPUT.PUT_LINE(
        RPAD('NUMRUN', 12) || ' ' ||
        RPAD('DVRUN', 6) || ' ' ||
        RPAD('NRO_TARJETA', 15) || ' ' ||
        RPAD('NRO_TRANSACCION', 15) || ' ' ||
        RPAD('FECHA', 12) || ' ' ||
        RPAD('TIPO', 30) || ' ' ||
        RPAD('MONTO', 15) || ' ' ||
        'APORTE'
    );
    
    DBMS_OUTPUT.PUT_LINE(
        RPAD('-', 12, '-') || ' ' ||
        RPAD('-', 6, '-') || ' ' ||
        RPAD('-', 15, '-') || ' ' ||
        RPAD('-', 15, '-') || ' ' ||
        RPAD('-', 12, '-') || ' ' ||
        RPAD('-', 30, '-') || ' ' ||
        RPAD('-', 15, '-') || ' ' ||
        '------'
    );
    
    -- Datos de DETALLE_APORTE_SBIF
    FOR detalle IN (
        SELECT * FROM DETALLE_APORTE_SBIF ORDER BY fecha_transaccion, numrun
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(detalle.numrun, 12) || ' ' ||
            RPAD(detalle.dvrun, 6) || ' ' ||
            RPAD(detalle.nro_tarjeta, 15) || ' ' ||
            RPAD(detalle.nro_transaccion, 15) || ' ' ||
            RPAD(TO_CHAR(detalle.fecha_transaccion, 'DD/MM/YYYY'), 12) || ' ' ||
            RPAD(detalle.tipo_transaccion, 30) || ' ' ||
            RPAD(TO_CHAR(detalle.monto_transaccion, '$999G999G999'), 15) || ' ' ||
            TO_CHAR(detalle.aporte_sbif, '$999G999G999')
        );
    END LOOP;
    
    -- Mostrar RESUMEN_APORTE_SBIF
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== RESUMEN_APORTE_SBIF ===');
    
    -- Encabezado de la tabla
    DBMS_OUTPUT.PUT_LINE(
        RPAD('MES_ANNO', 10) || ' ' ||
        RPAD('TIPO_TRANSACCION', 30) || ' ' ||
        RPAD('MONTO_TOTAL', 15) || ' ' ||
        'APORTE_TOTAL'
    );
    
    DBMS_OUTPUT.PUT_LINE(
        RPAD('-', 10, '-') || ' ' ||
        RPAD('-', 30, '-') || ' ' ||
        RPAD('-', 15, '-') || ' ' ||
        '------------'
    );
    
    -- Datos de RESUMEN_APORTE_SBIF
    FOR resumen IN (
        SELECT * FROM RESUMEN_APORTE_SBIF ORDER BY mes_anno, tipo_transaccion
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(resumen.mes_anno, 10) || ' ' ||
            RPAD(resumen.tipo_transaccion, 30) || ' ' ||
            RPAD(TO_CHAR(resumen.monto_total_transacciones, '$999G999G999'), 15) || ' ' ||
            TO_CHAR(resumen.aporte_total_abif, '$999G999G999')
        );
    END LOOP;
    
    -- Mostrar resumen de conteo
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '==============================================================================');
    DBMS_OUTPUT.PUT_LINE('2. RESUMEN DE REGISTROS ALMACENADOS');
    DBMS_OUTPUT.PUT_LINE('==============================================================================');
    
    DECLARE
        v_count_detalle NUMBER;
        v_count_resumen NUMBER;
        v_total_monto_detalle NUMBER;
        v_total_aporte_detalle NUMBER;
    BEGIN
        SELECT COUNT(*), SUM(monto_transaccion), SUM(aporte_sbif) 
        INTO v_count_detalle, v_total_monto_detalle, v_total_aporte_detalle
        FROM DETALLE_APORTE_SBIF;
        
        SELECT COUNT(*) 
        INTO v_count_resumen 
        FROM RESUMEN_APORTE_SBIF;
        
        DBMS_OUTPUT.PUT_LINE('DETALLE_APORTE_SBIF: ' || v_count_detalle || ' registros');
        DBMS_OUTPUT.PUT_LINE('  - Total monto transacciones: ' || TO_CHAR(v_total_monto_detalle, '$999G999G999'));
        DBMS_OUTPUT.PUT_LINE('  - Total aporte SBIF: ' || TO_CHAR(v_total_aporte_detalle, '$999G999G999'));
        DBMS_OUTPUT.PUT_LINE('RESUMEN_APORTE_SBIF: ' || v_count_resumen || ' registros');
    END;
    
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '==============================================================================');
    DBMS_OUTPUT.PUT_LINE('PROCESO FINALIZADO - Datos almacenados en las tablas:');
    DBMS_OUTPUT.PUT_LINE('  - DETALLE_APORTE_SBIF');
    DBMS_OUTPUT.PUT_LINE('  - RESUMEN_APORTE_SBIF');
    DBMS_OUTPUT.PUT_LINE('==============================================================================');
    
EXCEPTION
    WHEN OTHERS THEN
        -- Cerrar cursores si están abiertos
        IF c_avances_detalle%ISOPEN THEN
            CLOSE c_avances_detalle;
        END IF;
        IF c_resumen%ISOPEN THEN
            CLOSE c_resumen;
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END;
/
-- ==============================================================
-- Título: Cálculo y reporte de aportes SBIF
-- ==============================================================
-- Descripción:
-- 1) Limpia tablas de detalle y resumen.
-- 2) Calcula aportes SBIF para Avance y Súper Avance.
-- 3) Inserta datos en tablas DETALLE_APORTE_SBIF y RESUMEN_APORTE_SBIF.
-- 4) Muestra resultados alineados por DBMS_OUTPUT.
-- 5) Maneja excepciones:
--    - Predefinida (NO_DATA_FOUND)
--    - Definida por el usuario
--    - No predefinida (OTHERS)
-- 6) Realiza COMMIT solo si se procesan todos los registros.
-- 7) Usa variable de sustitución para el período de ejecución.
-- ==============================================================

DECLARE
    -- ==========================
    -- Variable de entrada
    -- ==========================
    v_anio NUMBER := &ANIO;  -- Cambiado de :B_ANIO a &ANIO

    -- ==========================
    -- Variables de control
    -- ==========================
    v_contador        NUMBER := 0;
    v_total_registros NUMBER := 0;
    v_aporte          NUMBER;
    v_aporte_total    NUMBER;
    v_dummy           NUMBER;

    -- ==========================
    -- Excepción definida por el usuario
    -- ==========================
    ex_sin_transacciones EXCEPTION;

    -- ==========================
    -- Cursor DETALLE (mejorado con parámetro)
    -- ==========================
    CURSOR cur_detalle(p_anio NUMBER) IS
        SELECT
            c.numrun,
            c.dvrun,
            t.nro_tarjeta,
            t.nro_transaccion,
            t.fecha_transaccion,
            tt.nombre_tptran_tarjeta AS tipo_transaccion,
            t.monto_total_transaccion
        FROM transaccion_tarjeta_cliente t
        JOIN tarjeta_cliente tc
            ON t.nro_tarjeta = tc.nro_tarjeta
        JOIN cliente c
            ON tc.numrun = c.numrun
        JOIN tipo_transaccion_tarjeta tt
            ON t.cod_tptran_tarjeta = tt.cod_tptran_tarjeta
        WHERE tt.nombre_tptran_tarjeta IN
              ('Avance en Efectivo','Súper Avance en Efectivo')
          AND EXTRACT(YEAR FROM t.fecha_transaccion) = p_anio
        ORDER BY t.fecha_transaccion, c.numrun;

    -- ==========================
    -- Cursor RESUMEN
    -- ==========================
    CURSOR cur_resumen IS
        SELECT
            TO_CHAR(t.fecha_transaccion,'MMYYYY') AS mes_anno,
            tt.nombre_tptran_tarjeta AS tipo_transaccion,
            SUM(t.monto_total_transaccion) AS monto_total
        FROM transaccion_tarjeta_cliente t
        JOIN tipo_transaccion_tarjeta tt
            ON t.cod_tptran_tarjeta = tt.cod_tptran_tarjeta
        WHERE tt.nombre_tptran_tarjeta IN
              ('Avance en Efectivo','Súper Avance en Efectivo')
          AND EXTRACT(YEAR FROM t.fecha_transaccion) = v_anio
        GROUP BY
            TO_CHAR(t.fecha_transaccion,'MMYYYY'),
            tt.nombre_tptran_tarjeta
        ORDER BY
            mes_anno, tipo_transaccion;

    -- ==========================
    -- Función cálculo aporte SBIF
    -- ==========================
    FUNCTION calcular_aporte(p_monto NUMBER) RETURN NUMBER IS
        v_resultado NUMBER := 0;
    BEGIN
        SELECT TRUNC(p_monto * porc_aporte_sbif / 100)
        INTO v_resultado
        FROM tramo_aporte_sbif
        WHERE p_monto BETWEEN tramo_inf_av_sav AND tramo_sup_av_sav;

        RETURN v_resultado;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0;  -- Si no encuentra tramo, retorna 0
    END calcular_aporte;

BEGIN
    -- ==========================
    -- Limpieza de tablas
    -- ==========================
    DELETE FROM detalle_aporte_sbif;
    DELETE FROM resumen_aporte_sbif;

    -- =====================================================
    -- Excepción predefinida NO_DATA_FOUND
    -- Se activa si no existen transacciones para el año
    -- =====================================================
    SELECT 1
    INTO v_dummy
    FROM transaccion_tarjeta_cliente t
    JOIN tipo_transaccion_tarjeta tt
        ON t.cod_tptran_tarjeta = tt.cod_tptran_tarjeta
    WHERE tt.nombre_tptran_tarjeta IN
          ('Avance en Efectivo','Súper Avance en Efectivo')
      AND EXTRACT(YEAR FROM t.fecha_transaccion) = v_anio
      AND ROWNUM = 1;

    -- ==========================
    -- Conteo total de registros
    -- ==========================
    SELECT COUNT(*)
    INTO v_total_registros
    FROM transaccion_tarjeta_cliente t
    JOIN tipo_transaccion_tarjeta tt
        ON t.cod_tptran_tarjeta = tt.cod_tptran_tarjeta
    WHERE tt.nombre_tptran_tarjeta IN
          ('Avance en Efectivo','Súper Avance en Efectivo')
      AND EXTRACT(YEAR FROM t.fecha_transaccion) = v_anio;

    -- =====================================================
    -- Excepción definida por el usuario
    -- =====================================================
    IF v_total_registros = 0 THEN
        RAISE ex_sin_transacciones;
    END IF;

    -- ==========================
    -- Procesamiento DETALLE
    -- ==========================
    FOR d IN cur_detalle(v_anio) LOOP
        v_aporte := calcular_aporte(d.monto_total_transaccion);

        INSERT INTO detalle_aporte_sbif VALUES (
            d.numrun,
            d.dvrun,
            d.nro_tarjeta,
            d.nro_transaccion,
            d.fecha_transaccion,
            d.tipo_transaccion,
            TRUNC(d.monto_total_transaccion),
            v_aporte
        );

        v_contador := v_contador + 1;
    END LOOP;

    -- ==========================
    -- Procesamiento RESUMEN
    -- ==========================
    FOR r IN cur_resumen LOOP
        v_aporte_total := calcular_aporte(r.monto_total);

        INSERT INTO resumen_aporte_sbif VALUES (
            r.mes_anno,
            r.tipo_transaccion,
            TRUNC(r.monto_total),
            v_aporte_total
        );
    END LOOP;

    -- =====================================================
    -- Confirmación controlada
    -- =====================================================
    IF v_contador = v_total_registros THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE(
            'Proceso finalizado correctamente. Registros procesados: ' || v_contador
        );
    ELSE
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(
            'Proceso incompleto. No se realizó COMMIT.'
        );
    END IF;

    -- ==========================
    -- Mostrar DETALLE_APORTE_SBIF alineado
    -- ==========================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '===== DETALLE_APORTE_SBIF =====');
    DBMS_OUTPUT.PUT_LINE(
        RPAD('NUMRUN',10) || ' | ' ||
        RPAD('DVRU',4) || ' | ' ||
        RPAD('NRO_TARJETA',15) || ' | ' ||
        RPAD('NRO_TRANSACCION',15) || ' | ' ||
        RPAD('FECHA_TRANSACCI',15) || ' | ' ||
        RPAD('TIPO_TRANSACCION',25) || ' | ' ||
        RPAD('MONTO_TOTAL_TRANSACC',20) || ' | ' ||
        RPAD('APORTE_SBI',10)
    );

    FOR det IN (
        SELECT *
        FROM detalle_aporte_sbif
        ORDER BY fecha_transaccion, numrun
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            LPAD(det.numrun,10) || ' | ' ||
            RPAD(det.dvrun,4) || ' | ' ||
            LPAD(det.nro_tarjeta,15) || ' | ' ||
            LPAD(det.nro_transaccion,15) || ' | ' ||
            TO_CHAR(det.fecha_transaccion,'DD/MM/YYYY') || ' | ' ||
            RPAD(det.tipo_transaccion,25) || ' | ' ||
            LPAD(det.monto_transaccion,20) || ' | ' ||
            LPAD(det.aporte_sbif,10)
        );
    END LOOP;

    -- ==========================
    -- Mostrar RESUMEN_APORTE_SBIF alineado
    -- ==========================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '===== RESUMEN_APORTE_SBIF =====');
    DBMS_OUTPUT.PUT_LINE(
        RPAD('MES_ANNO',8) || ' | ' ||
        RPAD('TIPO_TRANSACCION',25) || ' | ' ||
        RPAD('MONTO_TOTAL_TRANSACC',20) || ' | ' ||
        RPAD('APORTE_TOTAL_AB',15)
    );

    FOR res IN (
        SELECT *
        FROM resumen_aporte_sbif
        ORDER BY mes_anno, tipo_transaccion
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(res.mes_anno,8) || ' | ' ||
            RPAD(res.tipo_transaccion,25) || ' | ' ||
            LPAD(res.monto_total_transacciones,20) || ' | ' ||
            LPAD(res.aporte_total_abif,15)
        );
    END LOOP;

-- =====================================================
-- MANEJO DE EXCEPCIONES
-- =====================================================
EXCEPTION
    -- Excepción predefinida
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE(
            'No existen transacciones para el año ' || v_anio
        );
        ROLLBACK;

    -- Excepción definida por el usuario
    WHEN ex_sin_transacciones THEN
        DBMS_OUTPUT.PUT_LINE(
            'Total de transacciones es cero para el año ' || v_anio
        );
        ROLLBACK;

    -- Excepción no predefinida
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(
            'Error inesperado: ' || SQLERRM
        );
        ROLLBACK;
END;
/
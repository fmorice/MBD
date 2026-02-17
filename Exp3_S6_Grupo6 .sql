-- =====================================================================
-- SOLUCIÓN: PROCEDIMIENTOS ALMACENADOS PARA GESTIÓN DE GASTOS COMUNES
-- Descripción: Gestión de departamentos con pago cero en gastos comunes
-- =====================================================================

-- =====================================================================
-- PROCEDIMIENTO 1: Insertar registro en GASTO_COMUN_PAGO_CERO
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_insertar_pago_cero(
    p_anno_mes_pcgc IN NUMBER,
    p_id_edif IN NUMBER,
    p_nombre_edif IN VARCHAR2,
    p_run_admin IN VARCHAR2,
    p_nombre_admin IN VARCHAR2,
    p_nro_depto IN NUMBER,
    p_run_resp IN VARCHAR2,
    p_nombre_resp IN VARCHAR2,
    p_valor_multa IN NUMBER,
    p_observacion IN VARCHAR2
) AS
BEGIN
    -- Insertar el registro en la tabla GASTO_COMUN_PAGO_CERO
    INSERT INTO GASTO_COMUN_PAGO_CERO (
        anno_mes_pcgc,
        id_edif,
        nombre_edif,
        run_administrador,
        nombre_admnistrador,
        nro_depto,
        run_responsable_pago_gc,
        nombre_responsable_pago_gc,
        valor_multa_pago_cero,
        observacion
    ) VALUES (
        p_anno_mes_pcgc,
        p_id_edif,
        p_nombre_edif,
        p_run_admin,
        p_nombre_admin,
        p_nro_depto,
        p_run_resp,
        p_nombre_resp,
        p_valor_multa,
        p_observacion
    );
    
    COMMIT;
    
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('Error: Registro duplicado para depto ' || p_nro_depto || ' del edificio ' || p_id_edif);
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al insertar: ' || SQLERRM);
        ROLLBACK;
END sp_insertar_pago_cero;
/

-- =====================================================================
-- PROCEDIMIENTO 2: Proceso Principal - Generación de información
-- de departamentos con pago cero y actualización de multas
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_procesar_pago_cero(
    p_anno_mes_proceso IN NUMBER,  -- Formato YYYYMM (ej: 202505 para mayo 2025)
    p_valor_uf IN NUMBER            -- Valor de la UF del día
) AS
    -- Variables para manejo de fechas
    v_anno_mes_anterior NUMBER;
    v_anno_mes_dos_meses NUMBER;
    v_fecha_actual DATE;
    v_fecha_pago_gc DATE;
    
    -- Variables para información del departamento
    v_id_edif NUMBER;
    v_nro_depto NUMBER;
    v_nombre_edif VARCHAR2(50);
    v_run_admin VARCHAR2(20);
    v_nombre_admin VARCHAR2(60);
    v_run_resp VARCHAR2(20);
    v_nombre_resp VARCHAR2(60);
    
    -- Variables para cálculo de multas
    v_tiene_pago_mes_anterior NUMBER;
    v_tiene_pago_dos_meses NUMBER;
    v_valor_multa NUMBER;
    v_observacion VARCHAR2(80);
    
    -- Cursor para obtener todos los gastos comunes del mes anterior
    CURSOR c_gastos_comunes IS
        SELECT 
            gc.id_edif,
            gc.nro_depto,
            e.nombre_edif,
            gc.fecha_pago_gc,
            gc.numrun_rpgc,
            a.numrun_adm
        FROM GASTO_COMUN gc
        INNER JOIN DEPARTAMENTO d ON gc.id_edif = d.id_edif AND gc.nro_depto = d.nro_depto
        INNER JOIN EDIFICIO e ON gc.id_edif = e.id_edif
        INNER JOIN ADMINISTRADOR a ON e.numrun_adm = a.numrun_adm
        WHERE gc.anno_mes_pcgc = v_anno_mes_anterior
        ORDER BY e.nombre_edif, gc.nro_depto;
        
BEGIN
    -- Calcular el período anterior (mes anterior)
    -- Si estamos en mayo (202505), el mes anterior es abril (202504)
    IF MOD(p_anno_mes_proceso, 100) = 1 THEN
        -- Si es enero, el mes anterior es diciembre del año anterior
        v_anno_mes_anterior := (TRUNC(p_anno_mes_proceso/100) - 1) * 100 + 12;
    ELSE
        v_anno_mes_anterior := p_anno_mes_proceso - 1;
    END IF;
    
    -- Calcular dos meses atrás
    IF MOD(v_anno_mes_anterior, 100) = 1 THEN
        v_anno_mes_dos_meses := (TRUNC(v_anno_mes_anterior/100) - 1) * 100 + 12;
    ELSE
        v_anno_mes_dos_meses := v_anno_mes_anterior - 1;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('PROCESANDO GASTOS COMUNES CON PAGO CERO');
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('Período a procesar: ' || p_anno_mes_proceso);
    DBMS_OUTPUT.PUT_LINE('Período base (mes anterior): ' || v_anno_mes_anterior);
    DBMS_OUTPUT.PUT_LINE('Dos meses atrás: ' || v_anno_mes_dos_meses);
    DBMS_OUTPUT.PUT_LINE('Valor UF: $' || p_valor_uf);
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    
    -- Limpiar la tabla GASTO_COMUN_PAGO_CERO para el período actual
    DELETE FROM GASTO_COMUN_PAGO_CERO WHERE anno_mes_pcgc = p_anno_mes_proceso;
    DBMS_OUTPUT.PUT_LINE('Registros anteriores eliminados de GASTO_COMUN_PAGO_CERO');
    
    -- Recorrer todos los gastos comunes del mes anterior
    FOR rec IN c_gastos_comunes LOOP
        -- Verificar si existe pago para el mes anterior
        SELECT COUNT(*)
        INTO v_tiene_pago_mes_anterior
        FROM PAGO_GASTO_COMUN
        WHERE anno_mes_pcgc = v_anno_mes_anterior
        AND id_edif = rec.id_edif
        AND nro_depto = rec.nro_depto;
        
        -- Si NO tiene pago en el mes anterior, es un deudor
        IF v_tiene_pago_mes_anterior = 0 THEN
            -- Verificar si también falta el pago de dos meses atrás
            SELECT COUNT(*)
            INTO v_tiene_pago_dos_meses
            FROM PAGO_GASTO_COMUN
            WHERE anno_mes_pcgc = v_anno_mes_dos_meses
            AND id_edif = rec.id_edif
            AND nro_depto = rec.nro_depto;
            
            -- Obtener información del administrador
            SELECT 
                TO_CHAR(a.numrun_adm) || '-' || a.dvrun_adm,
                TRIM(a.pnombre_adm) || ' ' || 
                CASE WHEN a.snombre_adm IS NOT NULL THEN TRIM(a.snombre_adm) || ' ' ELSE '' END ||
                TRIM(a.appaterno_adm) || ' ' || 
                CASE WHEN a.apmaterno_adm IS NOT NULL THEN TRIM(a.apmaterno_adm) ELSE '' END
            INTO v_run_admin, v_nombre_admin
            FROM ADMINISTRADOR a
            WHERE a.numrun_adm = rec.numrun_adm;
            
            -- Obtener información del responsable de pago
            SELECT 
                TO_CHAR(r.numrun_rpgc) || '-' || r.dvrun_rpgc,
                TRIM(r.pnombre_rpgc) || ' ' || 
                CASE WHEN r.snombre_rpgc IS NOT NULL THEN TRIM(r.snombre_rpgc) || ' ' ELSE '' END ||
                TRIM(r.appaterno_rpgc) || ' ' || 
                CASE WHEN r.apmaterno_rpgc IS NOT NULL THEN TRIM(r.apmaterno_rpgc) ELSE '' END
            INTO v_run_resp, v_nombre_resp
            FROM RESPONSABLE_PAGO_GASTO_COMUN r
            WHERE r.numrun_rpgc = rec.numrun_rpgc;
            
            -- Determinar multa y observación según regla de negocio
            IF v_tiene_pago_dos_meses = 0 THEN
                -- No pagó por más de un período: multa de 4 UF y corte efectivo
                v_valor_multa := ROUND(4 * p_valor_uf);
                v_observacion := 'Corte de combustible y agua el ' || TO_CHAR(rec.fecha_pago_gc, 'DD/MM/YYYY');
                
                DBMS_OUTPUT.PUT_LINE('Depto ' || rec.nro_depto || ' - Edificio ' || rec.nombre_edif || 
                                   ': SIN PAGO 2+ períodos - Multa 4 UF = $' || v_valor_multa);
            ELSE
                -- No pagó solo un período: multa de 2 UF y aviso de corte
                v_valor_multa := ROUND(2 * p_valor_uf);
                v_observacion := 'Se dará aviso de corte de combustible y agua';
                
                DBMS_OUTPUT.PUT_LINE('Depto ' || rec.nro_depto || ' - Edificio ' || rec.nombre_edif || 
                                   ': SIN PAGO 1 período - Multa 2 UF = $' || v_valor_multa);
            END IF;
            
            -- Insertar el registro en GASTO_COMUN_PAGO_CERO usando el procedimiento auxiliar
            sp_insertar_pago_cero(
                p_anno_mes_pcgc => p_anno_mes_proceso,
                p_id_edif => rec.id_edif,
                p_nombre_edif => rec.nombre_edif,
                p_run_admin => v_run_admin,
                p_nombre_admin => v_nombre_admin,
                p_nro_depto => rec.nro_depto,
                p_run_resp => v_run_resp,
                p_nombre_resp => v_nombre_resp,
                p_valor_multa => v_valor_multa,
                p_observacion => v_observacion
            );
            
            -- Actualizar la multa en la tabla GASTO_COMUN para el período actual
            UPDATE GASTO_COMUN
            SET multa_gc = v_valor_multa,
                monto_total_gc = monto_total_gc + v_valor_multa
            WHERE anno_mes_pcgc = p_anno_mes_proceso
            AND id_edif = rec.id_edif
            AND nro_depto = rec.nro_depto;
            
            IF SQL%ROWCOUNT > 0 THEN
                DBMS_OUTPUT.PUT_LINE('  -> Multa actualizada en GASTO_COMUN');
            END IF;
            
        END IF;
        
    END LOOP;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    DBMS_OUTPUT.PUT_LINE('PROCESO COMPLETADO EXITOSAMENTE');
    DBMS_OUTPUT.PUT_LINE('=======================================================');
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR en el proceso: ' || SQLERRM);
        RAISE;
END sp_procesar_pago_cero;
/


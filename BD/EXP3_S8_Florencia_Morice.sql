-- =============================================================================
-- SOLUCIÓN ACTIVIDAD SUMATIVA 3 - 
-- Hotel "La Última Oportunidad"
-- =============================================================================


-- =============================================================================
-- CASO 1: TRIGGER para actualización automática de TOTAL_CONSUMOS
-- Cada vez que se inserte, actualice o elimine un consumo, se actualiza
-- automáticamente el monto total del huésped en la tabla TOTAL_CONSUMOS
-- =============================================================================

-- Ejecución 1 
CREATE OR REPLACE TRIGGER trg_actualiza_total_consumos
AFTER INSERT OR UPDATE OR DELETE ON consumo
FOR EACH ROW
DECLARE
    v_existe NUMBER; -- Variable para verificar si el huésped ya existe en TOTAL_CONSUMOS
BEGIN
    -- INSERT: agregar el nuevo monto al total del huésped
    IF INSERTING THEN
        -- Verificar si el huésped ya tiene registro en TOTAL_CONSUMOS
        SELECT COUNT(*) INTO v_existe
        FROM total_consumos
        WHERE id_huesped = :NEW.id_huesped;

        IF v_existe = 0 THEN
            -- Si no existe, crear un nuevo registro con el monto del consumo
            INSERT INTO total_consumos (id_huesped, monto_consumos)
            VALUES (:NEW.id_huesped, :NEW.monto);
        ELSE
            -- Si ya existe, sumar el nuevo monto al total acumulado
            UPDATE total_consumos
            SET monto_consumos = monto_consumos + :NEW.monto
            WHERE id_huesped = :NEW.id_huesped;
        END IF;

    -- UPDATE: ajustar el total restando el monto anterior y sumando el nuevo
    ELSIF UPDATING THEN
        UPDATE total_consumos
        SET monto_consumos = monto_consumos - :OLD.monto + :NEW.monto
        WHERE id_huesped = :OLD.id_huesped;

    -- DELETE: restar del total el monto del consumo eliminado
    ELSIF DELETING THEN
        UPDATE total_consumos
        SET monto_consumos = monto_consumos - :OLD.monto
        WHERE id_huesped = :OLD.id_huesped;
    END IF;

END trg_actualiza_total_consumos;
/

-- =============================================================================
-- PRUEBA DEL TRIGGER
-- IMPORTANTE: ejecutar UNA SOLA VEZ
-- Limpieza previa para evitar duplicados si el bloque se ejecutó antes
-- =============================================================================

-- Ejecución 2 — Limpieza previa
BEGIN
    -- Revertir operaciones anteriores si existen
    DELETE FROM consumo WHERE id_reserva = 1587 AND id_huesped = 340006 AND monto = 150;
    UPDATE consumo SET monto = 99 WHERE id_consumo = 10688 AND monto = 95;
    INSERT INTO consumo (id_consumo, id_reserva, id_huesped, monto)
    SELECT 11473, 1545, 340657, 42 FROM dual
    WHERE NOT EXISTS (SELECT 1 FROM consumo WHERE id_consumo = 11473);
    COMMIT;
END;
/

-- Ejecución 3: Bloque de prueba del trigger
DECLARE
    v_max_id NUMBER; -- Almacena el último ID de consumo para generar el siguiente
BEGIN
    -- Obtener el último ID de consumo registrado
    SELECT MAX(id_consumo) INTO v_max_id FROM consumo;

    -- 1) Insertar nuevo consumo para huésped 340006, reserva 1587, monto US$150
    INSERT INTO consumo (id_consumo, id_reserva, id_huesped, monto)
    VALUES (v_max_id + 1, 1587, 340006, 150);

    -- 2) Eliminar el consumo con ID 11473
    DELETE FROM consumo WHERE id_consumo = 11473;

    -- 3) Actualizar a US$95 el monto del consumo con ID 10688
    UPDATE consumo SET monto = 95 WHERE id_consumo = 10688;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Prueba del trigger ejecutada correctamente.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- Verificación: los resultados deben coincidir con la Figura 2
-- TOTAL_CONSUMOS esperado: 340003=212, 340004=95, 340006=428, 340008=189, 340009=142
SELECT * FROM total_consumos
WHERE id_huesped IN (340003, 340004, 340006, 340008, 340009)
ORDER BY id_huesped;

-- CONSUMO: no debe existir ID 11473, sí debe existir el nuevo con monto 150
-- y el 10688 con monto 95
SELECT * FROM consumo
WHERE id_huesped IN (340003, 340004, 340006, 340008, 340009)
ORDER BY id_huesped, id_consumo;

-- Ejecución 4 — Ver tablas

-- Ver TOTAL_CONSUMOS 
SELECT * FROM total_consumos
WHERE id_huesped IN (340003, 340004, 340006, 340008, 340009)
ORDER BY id_huesped;

-- Ver CONSUMO 
SELECT * FROM consumo
WHERE id_huesped IN (340003, 340004, 340006, 340008, 340009)
ORDER BY id_huesped, id_consumo;
-- =============================================================================
-- CASO 2: PACKAGE, FUNCIONES Y PROCEDIMIENTO PRINCIPAL
-- =============================================================================

-- =============================================================================
-- PARTE 1: PACKAGE pkg_hotel
-- Contiene la función para calcular el monto de tours de un huésped
-- y una variable pública para almacenar dicho monto
-- =============================================================================

CREATE OR REPLACE PACKAGE pkg_hotel AS

    -- Variable pública para que el procedimiento principal recupere el monto de tours
    g_monto_tours NUMBER := 0;

    -- Función pública: calcula el monto en dólares de los tours del huésped
    -- Si el huésped no ha tomado tours, retorna cero
    FUNCTION fn_monto_tours(p_id_huesped IN huesped.id_huesped%TYPE)
        RETURN NUMBER;

END pkg_hotel;
/

CREATE OR REPLACE PACKAGE BODY pkg_hotel AS

    FUNCTION fn_monto_tours(p_id_huesped IN huesped.id_huesped%TYPE)
        RETURN NUMBER
    IS
        v_total NUMBER := 0; -- Acumula el total de tours del huésped
    BEGIN
        -- Suma el valor de cada tour multiplicado por el número de personas
        SELECT NVL(SUM(t.valor_tour * ht.num_personas), 0)
        INTO v_total
        FROM huesped_tour ht
        JOIN tour t ON ht.id_tour = t.id_tour
        WHERE ht.id_huesped = p_id_huesped;

        RETURN v_total;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END fn_monto_tours;

END pkg_hotel;
/

-- Verificar que compiló sin errores
SHOW ERRORS PACKAGE pkg_hotel;
SHOW ERRORS PACKAGE BODY pkg_hotel;

-- Prueba: huésped 340001 tiene 2 personas x $65 Valle de la Luna = 130
SELECT pkg_hotel.fn_monto_tours(340001) AS monto_tours FROM dual;


-- =============================================================================
-- PARTE 2: FUNCIÓN fn_obtiene_agencia
-- Retorna el nombre de la agencia del huésped.
-- Si no registra agencia, retorna 'NO REGISTRA AGENCIA' y guarda el error.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_obtiene_agencia(
    p_id_huesped IN huesped.id_huesped%TYPE  -- ID del huésped a consultar
)
RETURN VARCHAR2
IS
    v_agencia   VARCHAR2(35);   -- Almacena el nombre de la agencia encontrada
    v_id_error  NUMBER;         -- ID generado por la secuencia para el registro de error
    v_msg       VARCHAR2(300);  -- Mensaje de error a registrar
BEGIN
    -- Busca el nombre de la agencia uniendo huesped con agencia por FK id_agencia
    SELECT a.nom_agencia
    INTO v_agencia
    FROM huesped h
    JOIN agencia a ON h.id_agencia = a.id_agencia
    WHERE h.id_huesped = p_id_huesped;

    RETURN v_agencia;

EXCEPTION
    -- Si el huésped no tiene agencia registrada
    WHEN NO_DATA_FOUND THEN
        SELECT sq_error.NEXTVAL INTO v_id_error FROM dual;
        v_msg := 'ORA-01403 ID_HUESPED: ' || TO_CHAR(p_id_huesped) || ' - ' || SQLERRM;
        INSERT INTO reg_errores (id_error, nomsubprograma, msg_error)
        VALUES (v_id_error, 'fn_obtiene_agencia', v_msg);
        RETURN 'NO REGISTRA AGENCIA';

    -- Captura cualquier otro error inesperado
    WHEN OTHERS THEN
        SELECT sq_error.NEXTVAL INTO v_id_error FROM dual;
        v_msg := 'Error ID_HUESPED: ' || TO_CHAR(p_id_huesped) || ' - ' || SQLERRM;
        INSERT INTO reg_errores (id_error, nomsubprograma, msg_error)
        VALUES (v_id_error, 'fn_obtiene_agencia', v_msg);
        RETURN 'NO REGISTRA AGENCIA';

END fn_obtiene_agencia;
/

-- Verificar que compiló sin errores
SHOW ERRORS FUNCTION fn_obtiene_agencia;

-- Prueba: debe retornar la agencia del huésped 340001
SELECT fn_obtiene_agencia(340001) AS agencia FROM dual;


-- =============================================================================
-- PARTE 3: FUNCIÓN fn_monto_consumos
-- Retorna el monto total de consumos del huésped desde TOTAL_CONSUMOS.
-- Si no registra consumos retorna 0 y registra el error.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_monto_consumos(
    p_id_huesped IN huesped.id_huesped%TYPE  -- ID del huésped a consultar
)
RETURN NUMBER
IS
    v_monto    NUMBER := 0;    -- Monto total de consumos encontrado
    v_id_error NUMBER;         -- ID generado por la secuencia para el registro de error
    v_msg      VARCHAR2(300);  -- Mensaje de error a registrar
BEGIN
    -- Busca el monto total de consumos en la tabla TOTAL_CONSUMOS
    SELECT monto_consumos
    INTO v_monto
    FROM total_consumos
    WHERE id_huesped = p_id_huesped;

    -- NVL por si el valor almacenado fuera NULL
    RETURN NVL(v_monto, 0);

EXCEPTION
    -- Si el huésped no registra consumos en TOTAL_CONSUMOS
    WHEN NO_DATA_FOUND THEN
        SELECT sq_error.NEXTVAL INTO v_id_error FROM dual;
        v_msg := 'ORA-01403 ID_HUESPED: ' || TO_CHAR(p_id_huesped) || ' - ' || SQLERRM;
        INSERT INTO reg_errores (id_error, nomsubprograma, msg_error)
        VALUES (v_id_error, 'fn_monto_consumos', v_msg);
        RETURN 0;

    -- Captura cualquier otro error inesperado
    WHEN OTHERS THEN
        SELECT sq_error.NEXTVAL INTO v_id_error FROM dual;
        v_msg := 'Error ID_HUESPED: ' || TO_CHAR(p_id_huesped) || ' - ' || SQLERRM;
        INSERT INTO reg_errores (id_error, nomsubprograma, msg_error)
        VALUES (v_id_error, 'fn_monto_consumos', v_msg);
        RETURN 0;

END fn_monto_consumos;
/

-- Verificar que compiló sin errores
SHOW ERRORS FUNCTION fn_monto_consumos;

-- Prueba: debe retornar 428 para el huésped 340006
SELECT fn_monto_consumos(340006) AS consumos FROM dual;


-- =============================================================================
-- PARTE 4: FUNCIÓN AUXILIAR fn_descuento_consumos
-- Retorna el porcentaje de descuento según el tramo de consumos del huésped
-- consultando la tabla TRAMOS_CONSUMOS
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_descuento_consumos(
    p_monto_consumos IN NUMBER  -- Monto total de consumos en dólares
)
RETURN NUMBER
IS
    v_pct NUMBER := 0; -- Porcentaje de descuento encontrado
BEGIN
    -- Busca el porcentaje según el tramo en que cae el monto
    SELECT pct
    INTO v_pct
    FROM tramos_consumos
    WHERE p_monto_consumos BETWEEN vmin_tramo AND vmax_tramo;

    RETURN NVL(v_pct, 0);

EXCEPTION
    -- Si el monto supera el tramo máximo, aplica el porcentaje más alto disponible
    WHEN NO_DATA_FOUND THEN
        SELECT MAX(pct) INTO v_pct FROM tramos_consumos;
        RETURN NVL(v_pct, 0);
    WHEN OTHERS THEN
        RETURN 0;
END fn_descuento_consumos;
/

-- Verificar que compiló sin errores
SHOW ERRORS FUNCTION fn_descuento_consumos;

-- Prueba: 428 dólares cae en tramo 5 (301-500) = 0.15
SELECT fn_descuento_consumos(428) AS pct_descuento FROM dual;


-- =============================================================================
-- PARTE 5: PROCEDIMIENTO PRINCIPAL prc_cobro_diario
-- Procesa todos los huéspedes con salida en la fecha indicada,
-- calcula alojamiento, consumos, tours, descuentos y total,
-- convierte todo a pesos chilenos y guarda en DETALLE_DIARIO_HUESPEDES
-- =============================================================================

CREATE OR REPLACE PROCEDURE prc_cobro_diario(
    p_fecha_proceso IN DATE,   -- Fecha del proceso (ej: DATE '2021-08-18')
    p_valor_dolar   IN NUMBER  -- Valor del dólar en pesos (ej: 915)
)
IS
    -- Cursor: obtiene huéspedes cuya fecha de salida (ingreso + estadia) = fecha del proceso
    CURSOR cur_huespedes IS
        SELECT
            h.id_huesped,
            h.nom_huesped || ' ' || h.appat_huesped || ' ' || h.apmat_huesped AS nombre,
            r.estadia,
            MIN(dr.id_habitacion) AS id_habitacion  -- Toma la primera habitación asignada
        FROM huesped h
        JOIN reserva r               ON h.id_huesped = r.id_huesped
        LEFT JOIN detalle_reserva dr ON r.id_reserva = dr.id_reserva
        WHERE TRUNC(r.ingreso + r.estadia) = TRUNC(p_fecha_proceso)
        GROUP BY h.id_huesped,
                 h.nom_huesped || ' ' || h.appat_huesped || ' ' || h.apmat_huesped,
                 r.estadia;

    -- Variables para los cálculos de cada huésped
    v_agencia           VARCHAR2(40);
    v_valor_hab         NUMBER;
    v_valor_minibar     NUMBER;
    v_alojamiento_clp   NUMBER;
    v_consumos_usd      NUMBER;
    v_consumos_clp      NUMBER;
    v_tours_usd         NUMBER;
    v_tours_clp         NUMBER;
    v_subtotal_clp      NUMBER;
    v_pct_desc_consumos NUMBER;
    v_desc_consumos_clp NUMBER;
    v_desc_agencia_clp  NUMBER;
    v_total_clp         NUMBER;

BEGIN
    -- Limpiar tablas de resultado y errores antes de iniciar el proceso
    DELETE FROM detalle_diario_huespedes;
    DELETE FROM reg_errores;

    -- Recorrer cada huésped con salida en la fecha del proceso
    FOR rec IN cur_huespedes LOOP
        BEGIN
            -- 1. Obtener agencia del huésped usando la función almacenada
            v_agencia := fn_obtiene_agencia(rec.id_huesped);

            -- 2. Calcular alojamiento: (habitacion + minibar) * dias * valor dólar
            --    Si no tiene habitación asignada, el alojamiento es 0
            IF rec.id_habitacion IS NOT NULL THEN
                SELECT valor_habitacion, valor_minibar
                INTO v_valor_hab, v_valor_minibar
                FROM habitacion
                WHERE id_habitacion = rec.id_habitacion;
                v_alojamiento_clp := ROUND((v_valor_hab + v_valor_minibar) * rec.estadia * p_valor_dolar);
            ELSE
                v_alojamiento_clp := 0;
            END IF;

            -- 3. Obtener consumos en dólares y convertir a pesos
            v_consumos_usd := fn_monto_consumos(rec.id_huesped);
            v_consumos_clp := ROUND(v_consumos_usd * p_valor_dolar);

            -- 4. Obtener monto de tours desde el package y convertir a pesos
            pkg_hotel.g_monto_tours := pkg_hotel.fn_monto_tours(rec.id_huesped);
            v_tours_usd := pkg_hotel.g_monto_tours;
            v_tours_clp := ROUND(v_tours_usd * p_valor_dolar);

            -- 5. Calcular subtotal: alojamiento + consumos + tours + cargo fijo $35.000
            v_subtotal_clp := v_alojamiento_clp + v_consumos_clp + v_tours_clp + 35000;

            -- 6. Calcular descuento sobre consumos según tramo (función auxiliar)
            v_pct_desc_consumos := fn_descuento_consumos(v_consumos_usd);
            v_desc_consumos_clp := ROUND(v_consumos_clp * v_pct_desc_consumos);

            -- 7. Calcular descuento de agencia: solo aplica 12% para VIAJES ALBERTI
            IF UPPER(v_agencia) = 'VIAJES ALBERTI' THEN
                v_desc_agencia_clp := ROUND(v_subtotal_clp * 0.12);
            ELSE
                v_desc_agencia_clp := 0;
            END IF;

            -- 8. Calcular total: subtotal menos ambos descuentos
            v_total_clp := v_subtotal_clp - v_desc_consumos_clp - v_desc_agencia_clp;

            -- 9. Insertar resultado en DETALLE_DIARIO_HUESPEDES
            INSERT INTO detalle_diario_huespedes (
                id_huesped, nombre, agencia,
                alojamiento, consumos, tours,
                subtotal_pago, descuento_consumos, descuentos_agencia, total
            ) VALUES (
                rec.id_huesped, rec.nombre, v_agencia,
                v_alojamiento_clp, v_consumos_clp, v_tours_clp,
                v_subtotal_clp, v_desc_consumos_clp, v_desc_agencia_clp, v_total_clp
            );

        EXCEPTION
            WHEN OTHERS THEN
                -- Si falla un huésped, continúa con el siguiente sin interrumpir el proceso
                DBMS_OUTPUT.PUT_LINE('Error huesped ' || rec.id_huesped || ': ' || SQLERRM);
        END;
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Proceso finalizado correctamente.');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error general: ' || SQLERRM);
END prc_cobro_diario;
/

-- Verificar que compiló sin errores
SHOW ERRORS PROCEDURE prc_cobro_diario;

-- =============================================================================
-- EJECUCIÓN DEL PROCEDIMIENTO PRINCIPAL
-- Fecha del proceso: 18/08/2021 | Valor dólar: $915
-- =============================================================================

BEGIN
    prc_cobro_diario(
        p_fecha_proceso => DATE '2021-08-18',
        p_valor_dolar   => 915
    );
END;
/

-- =============================================================================
-- VERIFICACIÓN FINAL
-- =============================================================================

-- Tabla DETALLE_DIARIO_HUESPEDES con todos los cálculos
SELECT * FROM detalle_diario_huespedes ORDER BY id_huesped;

-- Tabla REG_ERRORES con huéspedes sin agencia o sin consumos registrados
SELECT * FROM reg_errores ORDER BY id_error;

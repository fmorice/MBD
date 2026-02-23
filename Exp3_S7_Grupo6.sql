
-- Caso Semana 7: Clínica MAXSALUD - Pagos Morosos
-- ============================================================

-- ============================================================
-- PASO 1: CREACIÓN DEL PACKAGE PKG_PAGO_MOROSO
-- Contiene: función de descuento 3ra edad + dos variables públicas
-- ============================================================

CREATE OR REPLACE PACKAGE PKG_PAGO_MOROSO AS

    -- Variable pública para almacenar el valor de la multa por día de atraso
    v_valor_multa        NUMBER(8) := 0;

    -- Variable pública para almacenar el valor de descuento de la multa (3ra edad)
    v_descuento_multa    NUMBER(8) := 0;

    -- Función pública que obtiene el porcentaje de descuento de multa
    -- para pacientes mayores de 70 años, consultando la tabla PORC_DESCTO_3RA_EDAD.
    -- Retorna el porcentaje (NUMBER), o 0 si no aplica descuento.
    FUNCTION FN_OBTENER_DESCUENTO_3RA_EDAD(p_edad IN NUMBER) RETURN NUMBER;

END PKG_PAGO_MOROSO;
/

CREATE OR REPLACE PACKAGE BODY PKG_PAGO_MOROSO AS

    FUNCTION FN_OBTENER_DESCUENTO_3RA_EDAD(p_edad IN NUMBER) RETURN NUMBER IS
        -- Variable que almacenará el porcentaje de descuento encontrado
        v_porcentaje  NUMBER(4) := 0;
    BEGIN
        -- Solo aplica para mayores de 70 años
        IF p_edad > 70 THEN
            BEGIN
                -- Busca el porcentaje de descuento según el rango de edad en la tabla
                SELECT porcentaje_descto
                  INTO v_porcentaje
                  FROM PORC_DESCTO_3RA_EDAD
                 WHERE p_edad >= anno_ini
                   AND p_edad <= anno_ter;
            EXCEPTION
                -- Si no encuentra un rango exacto, el descuento es 0
                WHEN NO_DATA_FOUND THEN
                    v_porcentaje := 0;
            END;
        END IF;

        RETURN v_porcentaje;
    END FN_OBTENER_DESCUENTO_3RA_EDAD;

END PKG_PAGO_MOROSO;
/


-- ============================================================
-- PASO 2: FUNCIÓN ALMACENADA FN_OBTENER_ESPECIALIDAD
-- Retorna el nombre de la especialidad médica según el esp_id del médico
-- ============================================================

CREATE OR REPLACE FUNCTION FN_OBTENER_ESPECIALIDAD(p_med_run IN NUMBER)
RETURN VARCHAR2 IS
    -- Variable para guardar el nombre de la especialidad
    v_especialidad  ESPECIALIDAD.nombre%TYPE;
BEGIN
    -- Obtiene el nombre de la especialidad a partir del RUN del médico
    SELECT e.nombre
      INTO v_especialidad
      FROM ESPECIALIDAD e
      JOIN MEDICO m ON m.esp_id = e.esp_id
     WHERE m.med_run = p_med_run;

    RETURN v_especialidad;

EXCEPTION
    -- Si no se encuentra el médico o especialidad, retorna 'No encontrada'
    WHEN NO_DATA_FOUND THEN
        RETURN 'No encontrada';
END FN_OBTENER_ESPECIALIDAD;
/


-- ============================================================
-- PASO 3: PROCEDIMIENTO ALMACENADO SP_GENERAR_PAGOS_MOROSOS
-- Genera la información de todas las atenciones médicas pagadas
-- fuera de plazo en el año anterior a la ejecución del proceso.
-- Utiliza los constructores del Package y la Función Almacenada.
-- ============================================================

CREATE OR REPLACE PROCEDURE SP_GENERAR_PAGOS_MOROSOS IS

    -- VARRAY para almacenar los valores de multa por especialidad
    -- Orden: Traumatologia, Gastroenterologia, Neurologia, Geriatria,
    --        Oftalmologia, Pediatria, Medicina General, Ginecologia, Dermatologia
    TYPE T_MULTAS IS VARRAY(9) OF NUMBER(8);
    v_multas T_MULTAS := T_MULTAS(1300, 2000, 1700, 1100, 1900, 1700, 1200, 2000, 2300);
    -- Nota: Neurología y Pediatría comparten valor ($1.700)
    -- Los índices corresponden a esp_id: 100=Traumatologia, 200=Gastroenterologia,
    -- 300=Neurologia, 400=Geriatria, 500=Oftalmologia, 600=Pediatria,
    -- 700=Medicina General, 800=Ginecologia, 900=Dermatologia

    -- Variables de trabajo
    v_anno_proceso      NUMBER(4);      -- Año del que se procesará la información
    v_edad_paciente     NUMBER(3);      -- Edad del paciente al momento de la atención
    v_dias_mora         NUMBER(3);      -- Días de morosidad
    v_especialidad      VARCHAR2(30);   -- Nombre de la especialidad
    v_esp_id            NUMBER(3);      -- ID de la especialidad del médico
    v_indice_varray     NUMBER(2);      -- Índice para acceder al VARRAY de multas
    v_multa_base        NUMBER(8);      -- Multa sin descuento
    v_descuento_porc    NUMBER(4);      -- Porcentaje de descuento si aplica
    v_multa_final       NUMBER(8);      -- Multa final a cobrar
    v_observacion       VARCHAR2(100);  -- Observación del cobro

    -- Cursor principal: selecciona atenciones morosas del año anterior
    CURSOR c_morosos IS
        SELECT
            p.pac_run,
            p.dv_run                                         AS pac_dv_run,
            p.pnombre || ' ' || p.snombre || ' ' ||
            p.apaterno || ' ' || p.amaterno                 AS pac_nombre,
            a.ate_id,
            pa.fecha_venc_pago,
            pa.fecha_pago,
            a.costo,
            a.med_run,
            m.esp_id,
            TRUNC(MONTHS_BETWEEN(pa.fecha_pago, 
                  TO_DATE('01-01-' || TO_CHAR(pa.fecha_pago,'YYYY'),'DD-MM-YYYY'))) AS dummy,
            pa.fecha_pago - pa.fecha_venc_pago               AS dias_mora,
            TRUNC(MONTHS_BETWEEN(pa.fecha_venc_pago, p.fecha_nacimiento) / 12) AS edad_paciente
        FROM ATENCION a
        JOIN PAGO_ATENCION pa  ON pa.ate_id = a.ate_id
        JOIN PACIENTE p        ON p.pac_run = a.pac_run
        JOIN MEDICO m          ON m.med_run = a.med_run
        WHERE EXTRACT(YEAR FROM pa.fecha_venc_pago) = EXTRACT(YEAR FROM SYSDATE) - 1
          AND pa.fecha_pago > pa.fecha_venc_pago   -- Solo pagos fuera de plazo
        ORDER BY pa.fecha_venc_pago ASC, p.apaterno ASC;

BEGIN
    -- Año que se está procesando (año anterior)
    v_anno_proceso := EXTRACT(YEAR FROM SYSDATE) - 1;

    -- Truncar la tabla PAGO_MOROSO para limpiar datos anteriores del proceso
    EXECUTE IMMEDIATE 'TRUNCATE TABLE PAGO_MOROSO';

    -- Recorrer el cursor de atenciones morosas
    FOR reg IN c_morosos LOOP

        -- Calcular días de morosidad
        v_dias_mora := reg.dias_mora;

        -- Obtener la especialidad del médico usando la Función Almacenada
        v_especialidad := FN_OBTENER_ESPECIALIDAD(reg.med_run);

        -- Obtener el esp_id para mapear al VARRAY
        v_esp_id := reg.esp_id;

        -- Determinar el índice del VARRAY según el esp_id de la especialidad
        -- esp_id: 100=Traumatologia(1), 200=Gastroenterologia(2), 300=Neurologia(3),
        --         400=Geriatria(4), 500=Oftalmologia(5), 600=Pediatria(6),
        --         700=Medicina General(7), 800=Ginecologia(8), 900=Dermatologia(9)
        IF v_esp_id = 100 THEN
            v_indice_varray := 1;
        ELSIF v_esp_id = 200 THEN
            v_indice_varray := 2;
        ELSIF v_esp_id = 300 THEN
            v_indice_varray := 3;
        ELSIF v_esp_id = 400 THEN
            v_indice_varray := 4;
        ELSIF v_esp_id = 500 THEN
            v_indice_varray := 5;
        ELSIF v_esp_id = 600 THEN
            v_indice_varray := 6;
        ELSIF v_esp_id = 700 THEN
            v_indice_varray := 7;
        ELSIF v_esp_id = 800 THEN
            v_indice_varray := 8;
        ELSIF v_esp_id = 900 THEN
            v_indice_varray := 9;
        ELSE
            v_indice_varray := 7; -- Por defecto Medicina General
        END IF;

        -- Obtener valor de multa por día desde el VARRAY y almacenar en variable pública del Package
        PKG_PAGO_MOROSO.v_valor_multa := v_multas(v_indice_varray);

        -- Calcular multa base (valor por día * días de morosidad)
        v_multa_base := PKG_PAGO_MOROSO.v_valor_multa * v_dias_mora;

        -- Calcular edad del paciente a la fecha de vencimiento del pago
        v_edad_paciente := TRUNC(MONTHS_BETWEEN(reg.fecha_venc_pago, 
                           (SELECT fecha_nacimiento FROM PACIENTE WHERE pac_run = reg.pac_run)) / 12);

        -- Verificar si el paciente tiene más de 70 años para aplicar descuento
        -- Usar la función del Package para obtener el porcentaje de descuento
        v_descuento_porc := PKG_PAGO_MOROSO.FN_OBTENER_DESCUENTO_3RA_EDAD(v_edad_paciente);

        -- Almacenar el porcentaje de descuento en la variable pública del Package
        PKG_PAGO_MOROSO.v_descuento_multa := v_descuento_porc;

        -- Aplicar descuento si corresponde (paciente mayor de 70 años)
        IF v_descuento_porc > 0 THEN
            -- Calcular monto del descuento y aplicarlo a la multa base
            v_multa_final := v_multa_base - ROUND(v_multa_base * (v_descuento_porc / 100));
            -- Observación indicando el descuento aplicado
            v_observacion := 'Descuento 3ra edad ' || v_descuento_porc || '% aplicado. Edad paciente: ' || v_edad_paciente || ' años.';
        ELSE
            -- Sin descuento: la multa final es igual a la base
            v_multa_final := v_multa_base;
            -- Sin observación de descuento
            v_observacion := NULL;
        END IF;

        -- Insertar el registro en la tabla PAGO_MOROSO
        INSERT INTO PAGO_MOROSO (
            pac_run,
            pac_dv_run,
            pac_nombre,
            ate_id,
            fecha_venc_pago,
            fecha_pago,
            dias_morosidad,
            especialidad_atencion,
            costo_atencion,
            monto_multa,
            observacion
        ) VALUES (
            reg.pac_run,
            reg.pac_dv_run,
            reg.pac_nombre,
            reg.ate_id,
            reg.fecha_venc_pago,
            reg.fecha_pago,
            v_dias_mora,
            v_especialidad,
            reg.costo,
            v_multa_final,
            v_observacion
        );

    END LOOP;

    -- Confirmar la transacción
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Proceso SP_GENERAR_PAGOS_MOROSOS ejecutado correctamente.');
    DBMS_OUTPUT.PUT_LINE('Año procesado: ' || v_anno_proceso);

EXCEPTION
    WHEN OTHERS THEN
        -- En caso de error, revertir la transacción y mostrar el error
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR en SP_GENERAR_PAGOS_MOROSOS: ' || SQLERRM);
        RAISE;
END SP_GENERAR_PAGOS_MOROSOS;
/


-- ============================================================
-- PASO 4: EJECUCIÓN DEL PROCEDIMIENTO
-- ============================================================

-- Habilitar la salida por pantalla
SET SERVEROUTPUT ON;

-- Ejecutar el procedimiento
BEGIN
    SP_GENERAR_PAGOS_MOROSOS;
END;
/


-- ============================================================
-- PASO 5: VERIFICACIÓN DE RESULTADOS
-- Consulta para revisar los datos generados en PAGO_MOROSO
-- ============================================================

SELECT
    pac_run,
    pac_dv_run,
    pac_nombre,
    ate_id,
    TO_CHAR(fecha_venc_pago, 'DD/MM/YYYY') AS fecha_venc_pago,
    TO_CHAR(fecha_pago,      'DD/MM/YYYY') AS fecha_pago,
    dias_morosidad,
    especialidad_atencion,
    costo_atencion,
    monto_multa,
    observacion
FROM PAGO_MOROSO
ORDER BY fecha_venc_pago ASC, SUBSTR(pac_nombre, INSTR(pac_nombre,' ',1,2)+1) ASC;
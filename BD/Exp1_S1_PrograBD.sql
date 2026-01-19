-- ======================================================
-- BLOQUE PL/SQL ANÓNIMO PARA PROCESAR CLIENTES TODOSUMA
-- CASO 1 - BANK SOLUTIONS
-- ======================================================
-- Este bloque calcula y almacena información de clientes para el
-- programa TodoSuma, considerando créditos y montos en pesos
-- ======================================================

DECLARE
    -- Variables para almacenar datos del cliente
    v_nro_cliente CLIENTE.nro_cliente%TYPE;
    v_run_cliente VARCHAR2(15);
    v_nombre_cliente VARCHAR2(100);
    v_tipo_cliente VARCHAR2(30);
    v_monto_solic_creditos NUMBER(10) := 0;
    v_monto_pesos_todosuma NUMBER(8) := 0;
    
    -- Variables para iteración
    v_cliente_index NUMBER := 1;
    
    -- Tipo de registro para clientes a procesar
    TYPE t_cliente IS RECORD (
        nombre VARCHAR2(100),
        nro_cliente NUMBER
    );
    
    -- Tabla de clientes a procesar
    TYPE t_tabla_clientes IS TABLE OF t_cliente INDEX BY BINARY_INTEGER;
    v_clientes t_tabla_clientes;
    
BEGIN
    -- ======================================================
    -- 1. INICIALIZAR LISTA DE CLIENTES A PROCESAR
    -- ======================================================
    
    -- Sentencia PL/SQL para inicializar la tabla de clientes
    v_clientes(1).nombre := 'KAREN SOFIA PRADENAS MANDIOLA';
    v_clientes(2).nombre := 'SILVANA MARTINA VALENZUELA DUARTE';
    v_clientes(3).nombre := 'DENISSE ALICIA DIAZ MIRANDA';
    v_clientes(4).nombre := 'AMANDA ROMINA LIZANA MARAMBIO';
    v_clientes(5).nombre := 'LUIS CLAUDIO LUNA JORQUERA';
    
    -- ======================================================
    -- 2. PROCESAR CADA CLIENTE DE LA LISTA
    -- ======================================================
    
    -- Sentencia PL/SQL iterativa para procesar cada cliente
    WHILE v_cliente_index <= v_clientes.COUNT LOOP
        
        -- ======================================================
        -- 2.1 ELIMINAR CLIENTE SI EXISTE EN TABLA DESTINO
        -- ======================================================
        
        -- Sentencia SQL para eliminar cliente si ya existe
        DELETE FROM CLIENTE_TODOSUMA ct
        WHERE EXISTS (
            SELECT 1
            FROM CLIENTE c
            WHERE c.nro_cliente = ct.nro_cliente
              AND UPPER(c.pnombre || ' ' || COALESCE(c.snombre || ' ', '') || 
                   c.appaterno || ' ' || c.apmaterno) = v_clientes(v_cliente_index).nombre
        );
        
        DBMS_OUTPUT.PUT_LINE('Procesando cliente: ' || v_clientes(v_cliente_index).nombre);
        
        -- ======================================================
        -- 2.2 OBTENER DATOS DEL CLIENTE DESDE TABLA CLIENTE
        -- ======================================================
        
        -- Sentencia SQL para obtener datos básicos del cliente
        SELECT 
            c.nro_cliente,
            c.numrun || '-' || c.dvrun,
            c.pnombre || ' ' || COALESCE(c.snombre || ' ', '') || 
            c.appaterno || ' ' || c.apmaterno,
            tc.nombre_tipo_cliente
        INTO 
            v_nro_cliente,
            v_run_cliente,
            v_nombre_cliente,
            v_tipo_cliente
        FROM CLIENTE c
        INNER JOIN TIPO_CLIENTE tc ON c.cod_tipo_cliente = tc.cod_tipo_cliente
        WHERE UPPER(c.pnombre || ' ' || COALESCE(c.snombre || ' ', '') || 
              c.appaterno || ' ' || c.apmaterno) = v_clientes(v_cliente_index).nombre;
        
        -- Almacenar número de cliente en la tabla
        v_clientes(v_cliente_index).nro_cliente := v_nro_cliente;
        
        DBMS_OUTPUT.PUT_LINE('  Cliente encontrado: ' || v_nro_cliente || ' - ' || v_nombre_cliente);
        
        -- ======================================================
        -- 2.3 CALCULAR MONTO TOTAL DE CRÉDITOS SOLICITADOS
        -- ======================================================
        
        -- Sentencia SQL para sumar montos de créditos solicitados
        SELECT NVL(SUM(cc.monto_solicitado), 0)
        INTO v_monto_solic_creditos
        FROM CREDITO_CLIENTE cc
        WHERE cc.nro_cliente = v_nro_cliente;
        
        DBMS_OUTPUT.PUT_LINE('  Monto total créditos: $' || v_monto_solic_creditos);
        
        -- ======================================================
        -- 2.4 CALCULAR MONTO EN PESOS TODOSUMA (3% DEL MONTO DE CRÉDITOS)
        -- ======================================================
        
        -- Sentencia PL/SQL para cálculo del monto TodoSuma
        IF v_monto_solic_creditos > 0 THEN
            v_monto_pesos_todosuma := ROUND(v_monto_solic_creditos * 0.03);
        ELSE
            v_monto_pesos_todosuma := 0;
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('  Monto TodoSuma (3%): $' || v_monto_pesos_todosuma);
        
        -- ======================================================
        -- 2.5 INSERTAR DATOS EN TABLA CLIENTE_TODOSUMA
        -- ======================================================
        
        -- Sentencia SQL para insertar datos del cliente
        INSERT INTO CLIENTE_TODOSUMA (
            nro_cliente,
            run_cliente,
            nombre_cliente,
            tipo_cliente,
            monto_solic_creditos,
            monto_pesos_todosuma
        ) VALUES (
            v_nro_cliente,
            v_run_cliente,
            v_nombre_cliente,
            v_tipo_cliente,
            v_monto_solic_creditos,
            v_monto_pesos_todosuma
        );
        
        DBMS_OUTPUT.PUT_LINE('  Cliente insertado en CLIENTE_TODOSUMA');
        
        -- ======================================================
        -- 2.6 LIMPIAR VARIABLES PARA SIGUIENTE ITERACIÓN
        -- ======================================================
        
        v_monto_solic_creditos := 0;
        v_monto_pesos_todosuma := 0;
        
        v_cliente_index := v_cliente_index + 1;
        
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------');
        
    END LOOP;
    
    -- ======================================================
    -- 3. CONFIRMAR TRANSACCIÓN Y MOSTRAR RESUMEN
    -- ======================================================
    
    -- Sentencia PL/SQL para confirmar todos los cambios
    COMMIT;
    
    -- Mostrar resumen final
    DBMS_OUTPUT.PUT_LINE('=============================================');
    DBMS_OUTPUT.PUT_LINE('PROCESO COMPLETADO EXITOSAMENTE');
    DBMS_OUTPUT.PUT_LINE('=============================================');
    DBMS_OUTPUT.PUT_LINE('Total clientes procesados: ' || (v_cliente_index - 1));
    DBMS_OUTPUT.PUT_LINE('=============================================');
    
    -- Mostrar contenido final de la tabla
    DBMS_OUTPUT.PUT_LINE('CONTENIDO DE CLIENTE_TODOSUMA:');
    DBMS_OUTPUT.PUT_LINE('=============================================');
    
    FOR reg IN (
        SELECT nro_cliente, run_cliente, nombre_cliente, 
               tipo_cliente, monto_solic_creditos, monto_pesos_todosuma
        FROM CLIENTE_TODOSUMA
        ORDER BY nro_cliente
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('Cliente: ' || reg.nro_cliente || 
                            ' - ' || reg.nombre_cliente);
        DBMS_OUTPUT.PUT_LINE('RUN: ' || reg.run_cliente || 
                            ' - Tipo: ' || reg.tipo_cliente);
        DBMS_OUTPUT.PUT_LINE('Créditos: $' || reg.monto_solic_creditos || 
                            ' - TodoSuma: $' || reg.monto_pesos_todosuma);
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------');
    END LOOP;
    
EXCEPTION
    -- Manejo de excepciones
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: No se encontró el cliente: ' || 
                            v_clientes(v_cliente_index).nombre);
        DBMS_OUTPUT.PUT_LINE('Verifique que el nombre esté correctamente escrito en la base de datos.');
        ROLLBACK;
    WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Se encontraron múltiples clientes con el nombre: ' || 
                            v_clientes(v_cliente_index).nombre);
        ROLLBACK;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error procesando cliente: ' || v_clientes(v_cliente_index).nombre);
        ROLLBACK;
END;
/








-- ======================================================
-- BLOQUE PL/SQL ANÓNIMO PARA POSTERGACIÓN DE CUOTAS DE CRÉDITO
-- CASO 2 - BANK SOLUTIONS
-- ======================================================
-- Este bloque automatiza el proceso de postergación de cuotas
-- según las políticas del banco para diferentes tipos de crédito
-- ======================================================

DECLARE
    -- Declaración de variables de entrada (parámetros)
    v_numero_cliente CUOTA_CREDITO_CLIENTE.nro_solic_credito%TYPE := &numero_cliente;
    v_numero_solicitud CUOTA_CREDITO_CLIENTE.nro_solic_credito%TYPE := &numero_solicitud;
    v_cuotas_postergar NUMBER := &cuotas_postergar;
    
    -- Variables para almacenar datos del crédito
    v_tipo_credito CREDITO_CLIENTE.cod_credito%TYPE;
    v_ultima_cuota CUOTA_CREDITO_CLIENTE.nro_cuota%TYPE;
    v_ultima_fecha_vencimiento CUOTA_CREDITO_CLIENTE.fecha_venc_cuota%TYPE;
    v_valor_cuota CUOTA_CREDITO_CLIENTE.valor_cuota%TYPE;
    v_total_creditos_anio_anterior NUMBER;
    v_condonar_cuota CHAR(1) := 'N';
    
    -- Variables para cálculo de nuevas cuotas
    v_nueva_cuota NUMBER;
    v_nueva_fecha DATE;
    v_nuevo_monto NUMBER;
    v_tasa_interes NUMBER;
    v_nro_cliente_credito CREDITO_CLIENTE.nro_cliente%TYPE;
    
    -- Variables para control de ciclo
    i NUMBER;
    
BEGIN
    -- ======================================================
    -- 1. VALIDACIÓN INICIAL Y OBTENCIÓN DE DATOS DEL CRÉDITO
    -- ======================================================
    
    -- Obtener el tipo de crédito y datos de la última cuota
    -- Sentencia SQL para obtener información del crédito y última cuota
    SELECT 
        cc.cod_credito,
        (SELECT MAX(ccc.nro_cuota) 
         FROM CUOTA_CREDITO_CLIENTE ccc 
         WHERE ccc.nro_solic_credito = v_numero_solicitud),
        (SELECT MAX(ccc.fecha_venc_cuota) 
         FROM CUOTA_CREDITO_CLIENTE ccc 
         WHERE ccc.nro_solic_credito = v_numero_solicitud),
        (SELECT ccc.valor_cuota 
         FROM CUOTA_CREDITO_CLIENTE ccc 
         WHERE ccc.nro_solic_credito = v_numero_solicitud 
           AND ccc.nro_cuota = (SELECT MAX(nro_cuota) 
                               FROM CUOTA_CREDITO_CLIENTE 
                               WHERE nro_solic_credito = v_numero_solicitud)),
        cc.nro_cliente
    INTO 
        v_tipo_credito,
        v_ultima_cuota,
        v_ultima_fecha_vencimiento,
        v_valor_cuota,
        v_nro_cliente_credito
    FROM CREDITO_CLIENTE cc
    WHERE cc.nro_solic_credito = v_numero_solicitud;
    
    -- Verificar que el cliente existe y corresponde al crédito
    IF v_nro_cliente_credito != v_numero_cliente THEN
        -- Sentencia PL/SQL para manejo de excepción
        RAISE_APPLICATION_ERROR(-20001, 'El crédito no pertenece al cliente especificado');
    END IF;
    
    -- ======================================================
    -- 2. VERIFICAR SI EL CLIENTE TIENE MÁS DE UN CRÉDITO EN EL AÑO ANTERIOR
    -- ======================================================
    
    -- Sentencia SQL para contar créditos del año anterior
    SELECT COUNT(*)
    INTO v_total_creditos_anio_anterior
    FROM CREDITO_CLIENTE cc
    WHERE cc.nro_cliente = v_numero_cliente
      AND EXTRACT(YEAR FROM cc.fecha_solic_cred) = EXTRACT(YEAR FROM SYSDATE) - 1;
    
    -- Sentencia PL/SQL condicional para determinar si se condona la última cuota
    IF v_total_creditos_anio_anterior > 1 THEN
        v_condonar_cuota := 'S';
        DBMS_OUTPUT.PUT_LINE('Cliente con más de un crédito el año anterior. Se condonará la última cuota.');
    END IF;
    
    -- ======================================================
    -- 3. DETERMINAR TASA DE INTERÉS SEGÚN TIPO DE CRÉDITO Y CUOTAS
    -- ======================================================
    
    -- Sentencia PL/SQL condicional para establecer tasa de interés
    IF v_tipo_credito = 1 THEN -- Crédito Hipotecario
        IF v_cuotas_postergar = 1 THEN
            v_tasa_interes := 0; -- 0% de interés
        ELSIF v_cuotas_postergar = 2 THEN
            v_tasa_interes := 0.005; -- 0.5% de interés
        ELSE
            RAISE_APPLICATION_ERROR(-20002, 'Número de cuotas no válido para crédito hipotecario');
        END IF;
    ELSIF v_tipo_credito = 2 THEN -- Crédito de Consumo
        IF v_cuotas_postergar = 1 THEN
            v_tasa_interes := 0.01; -- 1% de interés
        ELSE
            RAISE_APPLICATION_ERROR(-20003, 'Número de cuotas no válido para crédito de consumo');
        END IF;
    ELSIF v_tipo_credito = 3 THEN -- Crédito Automotriz
        IF v_cuotas_postergar = 1 THEN
            v_tasa_interes := 0.02; -- 2% de interés
        ELSE
            RAISE_APPLICATION_ERROR(-20004, 'Número de cuotas no válido para crédito automotriz');
        END IF;
    ELSE
        RAISE_APPLICATION_ERROR(-20005, 'Tipo de crédito no válido para postergación');
    END IF;
    
    -- ======================================================
    -- 4. CONDONAR ÚLTIMA CUOTA SI CORRESPONDE
    -- ======================================================
    
    -- Sentencia PL/SQL condicional para condonar última cuota
    IF v_condonar_cuota = 'S' THEN
        -- Sentencia SQL para actualizar última cuota como pagada
        UPDATE CUOTA_CREDITO_CLIENTE
        SET fecha_pago_cuota = fecha_venc_cuota,
            monto_pagado = valor_cuota,
            saldo_por_pagar = 0,
            cod_forma_pago = 2 -- Transferencia Electrónica (como condonación)
        WHERE nro_solic_credito = v_numero_solicitud
          AND nro_cuota = v_ultima_cuota;
        
        DBMS_OUTPUT.PUT_LINE('Última cuota condonada: Cuota ' || v_ultima_cuota);
    END IF;
    
    -- ======================================================
    -- 5. GENERAR NUEVAS CUOTAS POSTERGADAS
    -- ======================================================
    
    -- Inicializar contador
    i := 1;
    
    -- Sentencia PL/SQL iterativa para crear nuevas cuotas
    WHILE i <= v_cuotas_postergar LOOP
        -- Calcular número de nueva cuota
        v_nueva_cuota := v_ultima_cuota + i;
        
        -- Calcular fecha de vencimiento (mes siguiente)
        v_nueva_fecha := ADD_MONTHS(v_ultima_fecha_vencimiento, i);
        
        -- Calcular monto con tasa de interés
        -- Sentencia PL/SQL para cálculo del monto
        v_nuevo_monto := v_valor_cuota + (v_valor_cuota * v_tasa_interes);
        
        -- Sentencia SQL para insertar nueva cuota
        INSERT INTO CUOTA_CREDITO_CLIENTE (
            nro_solic_credito,
            nro_cuota,
            fecha_venc_cuota,
            valor_cuota,
            fecha_pago_cuota,
            monto_pagado,
            saldo_por_pagar,
            cod_forma_pago
        ) VALUES (
            v_numero_solicitud,
            v_nueva_cuota,
            v_nueva_fecha,
            v_nuevo_monto,
            NULL,
            NULL,
            v_nuevo_monto,
            NULL
        );
        
        DBMS_OUTPUT.PUT_LINE('Cuota creada: Número ' || v_nueva_cuota || 
                            ', Fecha: ' || TO_CHAR(v_nueva_fecha, 'DD/MM/YYYY') || 
                            ', Monto: ' || v_nuevo_monto);
        
        i := i + 1;
    END LOOP;
    
    -- ======================================================
    -- 6. CONFIRMAR TRANSACCIÓN Y MOSTRAR RESUMEN
    -- ======================================================
    
    -- Sentencia PL/SQL para confirmar cambios
    COMMIT;
    
    -- Mostrar resumen de la operación
    DBMS_OUTPUT.PUT_LINE('=============================================');
    DBMS_OUTPUT.PUT_LINE('PROCESO DE POSTERGACIÓN COMPLETADO');
    DBMS_OUTPUT.PUT_LINE('=============================================');
    DBMS_OUTPUT.PUT_LINE('Cliente: ' || v_numero_cliente);
    DBMS_OUTPUT.PUT_LINE('Crédito: ' || v_numero_solicitud);
    DBMS_OUTPUT.PUT_LINE('Cuotas postergadas: ' || v_cuotas_postergar);
    DBMS_OUTPUT.PUT_LINE('Tasa aplicada: ' || (v_tasa_interes * 100) || '%');
    DBMS_OUTPUT.PUT_LINE('Última cuota condonada: ' || v_condonar_cuota);
    DBMS_OUTPUT.PUT_LINE('=============================================');
    
EXCEPTION
    -- Manejo de excepciones
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Error: No se encontraron datos para el crédito o cliente especificado');
        ROLLBACK;
    WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('Error: Se encontraron múltiples registros para los criterios de búsqueda');
        ROLLBACK;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/
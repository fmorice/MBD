-- ==========================================================
-- Semana 2 - Consultas SQL - 
-- Autor: Florencia Morice
-- Descripción: Aplicando funciones SQL avanzadas
-- ==========================================================

ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';

-- Variables de entorno para todo el script
DEFINE TIPOCAMBIO_DOLAR = 950;
DEFINE UMBRAL_BAJO = 40;
DEFINE UMBRAL_ALTO = 60;
DEFINE ANIO_ANTERIOR = 2024;  

/* ==========================================================
   CASO 1: ANÁLISIS DE FACTURAS - MEJORADO
   ----------------------------------------------------------
   Requerimientos:
   - Clasificar montos en Bajo, Medio, Alto.
   - Traducir formas de pago según código.
   - Mostrar RUT con 10 dígitos (relleno con ceros).
   - Filtrar facturas del año anterior.
   - Ordenar por fecha y monto descendente.

   ========================================================== */
SELECT 
    LPAD(f.rutcliente, 10, '0') AS RUT_CLIENTE,
    ROUND(f.neto) AS MONTO_NETO,
    TO_CHAR(f.fecha, 'DD/MM/YYYY') AS FECHA_FACTURA,
    
    -- Clasificación con múltiples condiciones
    CASE 
        WHEN f.neto <= 50000 THEN 'BAJO'
        WHEN f.neto <= 100000 THEN 'MEDIO'  
        WHEN f.neto <= 200000 THEN 'ALTO'
        ELSE 'MUY ALTO'
    END AS CLASIFICACION_MONTO,
    
    -- FORMA_PAGO con COALESCE y manejo de nulos
    COALESCE(
        CASE f.codpago
            WHEN 1 THEN 'EFECTIVO'
            WHEN 2 THEN 'TARJETA DEBITO' 
            WHEN 3 THEN 'TARJETA CREDITO'
            WHEN 4 THEN 'CHEQUE'
            ELSE NULL
        END, 'FORMA NO ESPECIFICADA'
    ) AS FORMA_PAGO,
    
    -- Información adicional calculada
    ROUND(f.neto * 1.19) AS MONTO_TOTAL,  -- Asumiendo 19% IVA
    TO_CHAR(f.fecha, 'YYYY-MM') AS MES_AÑO

FROM factura f
WHERE f.fecha >= ADD_MONTHS(TRUNC(SYSDATE, 'YEAR'), -12)
  AND f.fecha < TRUNC(SYSDATE, 'YEAR')
ORDER BY f.fecha DESC, f.neto DESC;


/* ==========================================================
   CASO 2: CLASIFICACIÓN DE CLIENTES 
   ----------------------------------------------------------
   Requerimientos:
   - Mostrar RUT invertido y relleno con '*'.
   - Manejar valores nulos (teléfono, comuna, correo).
   - Mostrar dominio de correo.
   - Categorizar crédito según SALDO / CREDITO:
       <50% es Bueno (mostrar diferencia)
       50–80% es Regular (mostrar saldo)
       >80% es Crítico
   - Filtrar clientes con estado 'A' y crédito > 0.
   - Ordenar por nombre ascendente.
   ========================================================== */
SELECT 
    -- RUT inverso (alternativa si REVERSE no existe)
    RPAD(SUBSTR(c.rutcliente, -LENGTH(c.rutcliente)), 10, '*') AS RUT_INVERSO,
    
    c.nombre AS NOMBRE_CLIENTE,
    
    -- Manejo de nulos con COALESCE anidado
    COALESCE(
        TO_CHAR(c.telefono),
        'Sin teléfono'
    ) AS TELEFONO,
    
    COALESCE(cm.descripcion, 'Sin comuna') AS COMUNA,
    
    -- Validación de email con REGEXP
    CASE 
        WHEN c.mail IS NULL THEN 'Correo no registrado'
        WHEN REGEXP_LIKE(c.mail, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') THEN c.mail
        ELSE 'Formato de correo inválido'
    END AS CORREO_VALIDADO,
    
    -- Extracción de dominio con verificación
    CASE 
        WHEN c.mail IS NOT NULL AND INSTR(c.mail, '@') > 0 THEN
            SUBSTR(c.mail, INSTR(c.mail, '@') + 1)
        ELSE 'Sin dominio'
    END AS DOMINIO,
    
    c.credito,
    c.saldo,
    
    -- Clasificación con protección contra división por cero
    CASE 
        WHEN c.credito = 0 OR c.credito IS NULL THEN 'Sin crédito asignado'
        WHEN (c.saldo / NULLIF(c.credito, 0)) < 0.5 THEN 
            'Bueno: Dif ' || TO_CHAR(ROUND(c.credito - c.saldo))
        WHEN (c.saldo / NULLIF(c.credito, 0)) <= 0.8 THEN 
            'Regular: Saldo ' || TO_CHAR(ROUND(c.saldo))
        ELSE 'Crítico: ' || ROUND((c.saldo / c.credito) * 100) || '% usado'
    END AS CLASIFICACION_CREDITO,
    
    -- Indicador de riesgo adicional
    CASE 
        WHEN c.saldo > c.credito THEN 'SOBREPASA LÍMITE'
        WHEN (c.saldo / NULLIF(c.credito, 0)) > 0.9 THEN 'ALTO RIESGO'
        ELSE 'DENTRO DE LÍMITES'
    END AS INDICADOR_RIESGO

FROM cliente c
LEFT JOIN comuna cm ON c.codcomuna = cm.codcomuna
WHERE c.estado = 'A'
  AND COALESCE(c.credito, 0) > 0
ORDER BY c.nombre ASC;


/* ==========================================================
   CASO 3: STOCK DE PRODUCTOS 
   ----------------------------------------------------------
 Requerimientos:
   - Mostrar valor en USD (si no existe, 'Sin registro').
   - Calcular valor en pesos usando variable de tipo de cambio.
   - Alertas de stock:
        Sin datos si stock nulo
        Muy bajo si está < umbral bajo
        Reabastecer pronto si está entre umbrales
        OK si está sobre umbral alto
   - Descuento del 10% si totalstock > 80.
   - Mostrar solo productos con “zapato” en descripción y 
     procedencia = 'i'.
   - Ordenar por id de producto descendente.
   ========================================================== */

SELECT 
    p.codproducto AS ID_PRODUCTO,
    p.descripcion AS DESCRIPCION,
    INITCAP(p.procedencia) AS PROCEDENCIA, 
    
    -- VALOR USD con manejo completo de nulos
    CASE 
        WHEN p.valorcompradolar IS NULL THEN 'Sin registro'
        ELSE '$' || TO_CHAR(ROUND(p.valorcompradolar, 2), '999,999.99')
    END AS VALOR_USD_FORMATEADO,
    
    -- VALOR PESOS simplificado (NULL automático si valorcompradolar es NULL)
    p.valorcompradolar * &TIPOCAMBIO_DOLAR AS VALOR_PESOS,
    
    -- Formateo del valor en pesos
    CASE 
        WHEN p.valorcompradolar IS NOT NULL THEN
            '$' || TO_CHAR(ROUND(p.valorcompradolar * &TIPOCAMBIO_DOLAR), '999,999,999')
        ELSE 'No convertible'
    END AS VALOR_PESOS_FORMATEADO,
    
    p.totalstock AS TOTALSTOCK,
    
    -- ALERTA STOCK con más categorías
    CASE 
        WHEN p.totalstock IS NULL THEN ' Sin datos de stock'
        WHEN p.totalstock = 0 THEN 'STOCK AGOTADO'
        WHEN p.totalstock < &UMBRAL_BAJO THEN ' ¡ALERTA stock muy bajo!'
        WHEN p.totalstock BETWEEN &UMBRAL_BAJO AND &UMBRAL_ALTO THEN 'Reabastecer pronto'
        WHEN p.totalstock BETWEEN &UMBRAL_ALTO + 1 AND 100 THEN 'Stock adecuado'
        ELSE 'Stock óptimo'
    END AS ALERTA_STOCK_DETALLADA,
    
    -- VALOR FINAL con múltiples condiciones de descuento
    CASE 
        WHEN p.totalstock > 100 THEN p.vunitario * 0.85  -- 15% descuento
        WHEN p.totalstock > 80 THEN p.vunitario * 0.90   -- 10% descuento
        WHEN p.totalstock < 20 THEN p.vunitario * 1.10   -- 10% recargo por bajo stock
        ELSE p.vunitario
    END AS VALOR_FINAL,
    
    -- Indicador de rentabilidad
    CASE 
        WHEN p.valorcompradolar IS NOT NULL THEN
            ROUND(((p.vunitario - (p.valorcompradolar * &TIPOCAMBIO_DOLAR)) / 
                   (p.valorcompradolar * &TIPOCAMBIO_DOLAR)) * 100, 2)
        ELSE NULL
    END AS MARGEN_PORCENTAJE

FROM producto p
WHERE UPPER(p.descripcion) LIKE '%ZAPATO%' 
  AND UPPER(p.procedencia) = 'I'
  AND COALESCE(p.totalstock, 0) >= 0 
ORDER BY p.codproducto DESC;


/* ==========================================================
   CONSULTA ADICIONAL: RESUMEN EJECUTIVO
   ----------------------------------------------------------
   Demostración de funciones de agregación con manejo de nulos
   ========================================================== */

-- Resumen por clasificación de crédito (Caso 2)
SELECT 
    CLASIFICACION_CREDITO,
    COUNT(*) AS TOTAL_CLIENTES,
    ROUND(AVG(COALESCE(saldo, 0)), 2) AS SALDO_PROMEDIO,
    ROUND(AVG(COALESCE(credito, 0)), 2) AS CREDITO_PROMEDIO,
    SUM(COALESCE(saldo, 0)) AS SALDO_TOTAL
FROM (
    -- Subconsulta con la lógica del Caso 2
    SELECT 
        c.saldo,
        c.credito,
        CASE 
            WHEN c.credito = 0 OR c.credito IS NULL THEN 'Sin crédito asignado'
            WHEN (c.saldo / NULLIF(c.credito, 0)) < 0.5 THEN 'Bueno'
            WHEN (c.saldo / NULLIF(c.credito, 0)) <= 0.8 THEN 'Regular'
            ELSE 'Crítico'
        END AS CLASIFICACION_CREDITO
    FROM cliente c
    WHERE c.estado = 'A'
)
GROUP BY CLASIFICACION_CREDITO
ORDER BY TOTAL_CLIENTES DESC;


-- Limpieza de variables
UNDEFINE TIPOCAMBIO_DOLAR;
UNDEFINE UMBRAL_BAJO; 
UNDEFINE UMBRAL_ALTO;
UNDEFINE ANIO_ANTERIOR;
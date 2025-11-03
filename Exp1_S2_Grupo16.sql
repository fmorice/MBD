-- ==========================================================
-- Semana 2 - Consultas SQL
-- Autor: Florencia Morice
-- Descripción: Solución de los 3 casos del laboratorio 
--              "Creando consultas utilizando funciones SQL"
-- ==========================================================

ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';


/* ==========================================================
   CASO 1: ANÁLISIS DE FACTURAS
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
    CASE 
        WHEN f.neto <= 50000 THEN 'BAJO'
        WHEN f.neto BETWEEN 50001 AND 100000 THEN 'MEDIO'
        ELSE 'ALTO'
    END AS CLASIFICACION_MONTO,
    CASE 
        WHEN f.codpago = 1 THEN 'EFECTIVO'
        WHEN f.codpago = 2 THEN 'TARJETA DEBITO'
        WHEN f.codpago = 3 THEN 'TARJETA CREDITO'
        ELSE 'CHEQUE'
    END AS FORMA_PAGO
FROM factura f
WHERE EXTRACT(YEAR FROM f.fecha) = EXTRACT(YEAR FROM SYSDATE) - 1
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
    RPAD(REVERSE(c.rutcliente), 10, '*') AS RUT_INVERSO,
    c.nombre AS NOMBRE_CLIENTE,
    NVL(TO_CHAR(c.telefono), 'Sin teléfono') AS TELEFONO,
    NVL(cm.descripcion, 'Sin comuna') AS COMUNA,
    NVL(c.mail, 'Correo no registrado') AS CORREO,
    SUBSTR(c.mail, INSTR(c.mail, '@') + 1) AS DOMINIO,
    c.credito,
    c.saldo,
    CASE 
        WHEN (c.saldo / c.credito) < 0.5 THEN 'Bueno: Dif ' || TO_CHAR(c.credito - c.saldo)
        WHEN (c.saldo / c.credito) BETWEEN 0.5 AND 0.8 THEN 'Regular: Saldo ' || TO_CHAR(c.saldo)
        ELSE 'Crítico'
    END AS CLASIFICACION
FROM cliente c
LEFT JOIN comuna cm ON c.codcomuna = cm.codcomuna
WHERE c.estado = 'A'
  AND c.credito > 0
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

DEFINE TIPOCAMBIO_DOLAR = 950
DEFINE UMBRAL_BAJO = 40
DEFINE UMBRAL_ALTO = 60

SELECT 
    p.codproducto AS ID_PRODUCTO,
    p.descripcion AS DESCRIPCION,
    p.procedencia AS PROCEDENCIA,
    NVL(TO_CHAR(p.valorcompradolar), 'Sin registro') AS VALOR_USD,
    CASE 
        WHEN p.valorcompradolar IS NOT NULL THEN p.valorcompradolar * &TIPOCAMBIO_DOLAR
        ELSE NULL
    END AS VALOR_PESOS,
    p.totalstock AS TOTALSTOCK,
    CASE 
        WHEN p.totalstock IS NULL THEN 'Sin datos'
        WHEN p.totalstock < &UMBRAL_BAJO THEN '¡ALERTA stock muy bajo!'
        WHEN p.totalstock BETWEEN &UMBRAL_BAJO AND &UMBRAL_ALTO THEN '¡Reabastecer pronto!'
        ELSE 'OK'
    END AS ALERTA_STOCK,
    CASE 
        WHEN p.totalstock > 80 THEN p.vunitario * 0.9
        ELSE p.vunitario
    END AS VALOR_FINAL
FROM producto p
WHERE LOWER(p.descripcion) LIKE '%zapato%'
  AND LOWER(p.procedencia) = 'i'
ORDER BY p.codproducto DESC;
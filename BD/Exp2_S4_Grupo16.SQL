-- Caso 1: Listado de Trabajadores
SELECT 
    t.numrut || '-' || t.dvrut                                          AS "RUT",
    INITCAP(t.nombre) || ' ' || INITCAP(t.appaterno) || ' ' || 
    INITCAP(t.apmaterno)                                                AS "NOMBRE COMPLETO",
    INITCAP(cc.nombre_ciudad)                                           AS "CIUDAD",
    INITCAP(tt.desc_categoria)                                          AS "TIPO TRABAJADOR",
    '$' || TO_CHAR(t.sueldo_base, '9,999,999')                          AS "SUELDO BASE"
FROM trabajador t
INNER JOIN comuna_ciudad cc ON t.id_ciudad = cc.id_ciudad
INNER JOIN tipo_trabajador tt ON t.id_categoria_t = tt.id_categoria
WHERE t.sueldo_base BETWEEN 650000 AND 3000000
ORDER BY cc.nombre_ciudad DESC, t.sueldo_base ASC;


-- Caso 2: Listado Cajeros
SELECT 
    INITCAP(t.nombre) || ' ' || INITCAP(t.appaterno) || ' ' || INITCAP(t.apmaterno)                 AS "NOMBRE CAJERO",
    INITCAP(cc.nombre_ciudad)                                                                       AS "COMUNA",
    COUNT(tc.nro_ticket)                                                                            AS "CANTIDAD TICKETS",
    TO_CHAR(SUM(tc.monto_ticket), 'L999G999G999', 'NLS_CURRENCY=$')                                 AS "TOTAL VENDIDO",
    TO_CHAR(SUM(com.valor_comision), 'L999G999G999', 'NLS_CURRENCY=$')                              AS "COMISION TOTAL"

FROM trabajador t
JOIN comuna_ciudad cc ON t.id_ciudad = cc.id_ciudad
JOIN tickets_concierto tc ON t.numrut = tc.numrut_t
JOIN comisiones_ticket com ON tc.nro_ticket = com.nro_ticket
JOIN tipo_trabajador tt ON t.id_categoria_t = tt.id_categoria
WHERE UPPER(tt.desc_categoria) LIKE '%CAJERO%'
GROUP BY t.numrut, t.nombre, t.appaterno, t.apmaterno, cc.nombre_ciudad
HAVING SUM(tc.monto_ticket) > 50000
ORDER BY SUM(tc.monto_ticket) DESC;

-- Caso 3: Listado de Bonificaciones 
SELECT 
    TO_CHAR(t.numrut, '99G999G999') || '-' || t.dvrut                               AS "RUT Trabajador",
    INITCAP(t.nombre) || ' ' || INITCAP(t.appaterno) || ' ' || INITCAP(t.apmaterno) AS "Nombre Trabajador",
    TO_CHAR(t.fecing, 'YYYY')                                                       AS "AÑO INGRESO",
    FLOOR(MONTHS_BETWEEN(SYSDATE, t.fecing) / 12)                                   AS "AÑOS ANTIGÜEDAD",
    COUNT(af.numrut_carga)                                                          AS "NUM. CARGAS FAMILIARES",
    SUBSTR(i.nombre_isapre, 1, 10)                                                  AS "SISTEMA SALUD",
    TO_CHAR(t.sueldo_base, '$999,999,999')                                          AS "SUELDO BASE",

    CASE 
        WHEN UPPER(i.nombre_isapre) = 'FONASA' THEN 
            TO_CHAR(t.sueldo_base * 0.01, '$999,999,999')
        ELSE '$0'
    END AS "BONO FONASA",
    CASE 
        WHEN FLOOR(MONTHS_BETWEEN(SYSDATE, t.fecing) / 12) <= 10 THEN 
            TO_CHAR(t.sueldo_base * 0.10, '$999,999,999')
        ELSE 
            TO_CHAR(t.sueldo_base * 0.15, '$999,999,999')
    END AS "BONO ANTIGÜEDAD",
    a.nombre_afp AS "NOMBRE AFP",
    SUBSTR(ec.desc_estcivil, 1, 8) AS "ESTADO CIVIL"
FROM trabajador t
JOIN isapre i ON t.cod_isapre = i.cod_isapre
JOIN afp a ON t.cod_afp = a.cod_afp
LEFT JOIN asignacion_familiar af ON t.numrut = af.numrut_t
JOIN est_civil est ON t.numrut = est.numrut_t
JOIN estado_civil ec ON est.id_estcivil_est = ec.id_estcivil
WHERE est.fecter_estcivil IS NULL 
   OR est.fecter_estcivil > SYSDATE
GROUP BY 
    t.numrut, 
    t.dvrut, 
    t.nombre, 
    t.appaterno, 
    t.apmaterno, 
    t.fecing, 
    t.sueldo_base, 
    i.nombre_isapre, 
    a.nombre_afp, 
    ec.desc_estcivil
ORDER BY t.numrut ASC;
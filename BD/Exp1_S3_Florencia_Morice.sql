
-- Caso 1: Listado de Clientes con Rango de Renta
SELECT 
    TO_CHAR(c.numrut_cli, '99G999G999') || '-' || c.dvrut_cli AS "RUT CLIENTE",
    INITCAP(c.nombre_cli) || ' ' || INITCAP(c.appaterno_cli) || ' ' || INITCAP(c.apmaterno_cli) AS "NOMBRE COMPLETO",
    TO_CHAR(c.renta_cli, 'L999G999', 'NLS_CURRENCY=$') AS "RENTA",
    CASE 
        WHEN c.renta_cli > 500000 THEN 'TRAMO 1'
        WHEN c.renta_cli BETWEEN 400000 AND 500000 THEN 'TRAMO 2'
        WHEN c.renta_cli BETWEEN 200000 AND 399999 THEN 'TRAMO 3'
        ELSE 'TRAMO 4'
    END AS "TRAMO RENTA"
FROM cliente c
WHERE c.renta_cli BETWEEN &RENTA_MINIMA AND &RENTA_MAXIMA
    AND c.celular_cli IS NOT NULL
ORDER BY "NOMBRE COMPLETO" ASC;



-- Caso 2: Sueldo Promedio por Categoría de Empleado
SELECT 
    ce.desc_categoria_emp AS "CATEGORIA EMPLEADO",
    s.desc_sucursal AS "SUCURSAL",
    COUNT(e.numrut_emp) AS "CANTIDAD EMPLEADOS",
    TO_CHAR(AVG(e.sueldo_emp), 'L9G999G999', 'NLS_CURRENCY=$') AS "SUELDO PROMEDIO",
    TO_CHAR(MAX(e.sueldo_emp), 'L9G999G999', 'NLS_CURRENCY=$') AS "SUELDO MAXIMO",
    TO_CHAR(MIN(e.sueldo_emp), 'L9G999G999', 'NLS_CURRENCY=$') AS "SUELDO MINIMO",
    TO_CHAR(SUM(e.sueldo_emp), 'L9G999G999', 'NLS_CURRENCY=$') AS "TOTAL SUELDOS"
FROM empleado e
JOIN categoria_empleado ce ON e.id_categoria_emp = ce.id_categoria_emp
JOIN sucursal s ON e.id_sucursal = s.id_sucursal
GROUP BY ce.desc_categoria_emp, s.desc_sucursal, ce.id_categoria_emp, s.id_sucursal
HAVING AVG(e.sueldo_emp) > &SUELDO_PROMEDIO_MINIMO
ORDER BY AVG(e.sueldo_emp) DESC;

-- Caso 3: Arriendo Promedio por Tipo de Propiedad

SELECT 
    tp.desc_tipo_propiedad AS "TIPO PROPIEDAD",
    COUNT(p.nro_propiedad) AS "TOTAL PROPIEDADES",
    TO_CHAR(AVG(p.valor_arriendo), 'L9G999G999', 'NLS_CURRENCY=$') AS "ARRIENDO PROMEDIO",
    TO_CHAR(AVG(p.superficie), '999D99') AS "SUPERFICIE PROMEDIO",
    TO_CHAR(AVG(p.valor_arriendo / p.superficie), '99G999D99') AS "VALOR ARRIENDO M2",
    CASE 
        WHEN AVG(p.valor_arriendo / p.superficie) < 5000 THEN 'Económico'
        WHEN AVG(p.valor_arriendo / p.superficie) BETWEEN 5000 AND 10000 THEN 'Medio'
        ELSE 'Alto'
    END AS "CLASIFICACION"
FROM propiedad p
JOIN tipo_propiedad tp ON p.id_tipo_propiedad = tp.id_tipo_propiedad
GROUP BY tp.desc_tipo_propiedad, tp.id_tipo_propiedad
HAVING AVG(p.valor_arriendo / p.superficie) > 1000
ORDER BY AVG(p.valor_arriendo / p.superficie) DESC;
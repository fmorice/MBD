-- Caso 1: Listado de Clientes elegibles para cobranzas
SELECT 
-- Formatear RUT con separadores de miles y guión para dígito verificador
    TO_CHAR(c.numrun, '09G999G999')                             AS "RUT CLIENTE",

-- Construir nombre completo capitalizando cada parte y manejando valores nulos
    INITCAP(c.pnombre) || ' ' || 
    NVL(INITCAP(c.snombre), '') || ' ' ||
    INITCAP(c.appaterno) || ' ' ||
    NVL(INITCAP(c.apmaterno), '')                               AS "NOMBRE CLIENTE",

-- Profesión en mayúsculas para consistencia visual
    UPPER(po.nombre_prof_ofic)                                  AS "PROFESION CLIENTE",

 -- Fecha de inscripción en formato día-mes-año 
    TO_CHAR(c.fecha_inscripcion, 'DD-MM-YYYY')                  AS "FECHA INSCRIPCION",
    c.direccion                                                 AS "DIRECCION CLIENTE"
FROM CLIENTE c
INNER JOIN PROFESION_OFICIO po ON c.cod_prof_ofic = po.cod_prof_ofic
INNER JOIN TIPO_CLIENTE tc ON c.cod_tipo_cliente = tc.cod_tipo_cliente

-- Filtrar solo trabajadores dependientes
WHERE tc.nombre_tipo_cliente = 'Trabajadores dependientes'

-- Filtrar por profesiones específicas (Contador o Vendedor)
  AND UPPER(po.nombre_prof_ofic) IN ('CONTADOR', 'VENDEDOR')
  AND EXTRACT(YEAR FROM c.fecha_inscripcion) > (

    -- Subconsulta: Calcular año promedio de inscripción redondeado
      SELECT ROUND(AVG(EXTRACT(YEAR FROM fecha_inscripcion)))
      FROM CLIENTE
      WHERE fecha_inscripcion IS NOT NULL
  )
  -- Ordenar resultados por RUT de forma ascendente para consistencia
ORDER BY c.numrun ASC;




-- CASO 2: LISTADO DE CLIENTES PARA AUMENTO DE CRÉDITO
-- Objetivo: Mostrar clientes elegibles para aumento de crédito
SELECT 
    -- RUT del cliente (ya formateado durante la inserción)
    rut_cliente                                                 AS "RUT CLIENTE",
    
    -- Edad del cliente calculada
    edad                                                        AS "EDAD",
    
    -- Cupo disponible actual formateado como moneda
    TO_CHAR(cupo_disponible_compra, 'L999G999G999')             AS "CUPO_DISPONIBLE_COMPRA",
    
    -- Tipo de cliente (Trabajadores dependientes, independientes, etc.)
    tipo_cliente                                                AS "TIPO_CLIENTE",
    
    -- Máximo cupo del año anterior formateado como moneda
    TO_CHAR(cupo_anio_pasado, 'L999G999G999')                   AS "MAXIMO CUPO AÑO ANTERIOR"
    -- ↑ NOTA: SE ELIMINÓ LA COMA EXTRA QUE CAUSABA EL ERROR

FROM CLIENTES_CUPOS_COMPRA

-- Ordenar por edad de forma ascendente para análisis demográfico
ORDER BY edad ASC;



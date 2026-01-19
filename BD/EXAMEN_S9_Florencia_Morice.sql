--Paso 1: CREAR LOS USUARIOS 

-- 1. ELIMINAR USUARIOS EXISTENTES (CON CASCADE)
DROP USER PRY2205_EFT CASCADE;
DROP USER PRY2205_EFT_DES CASCADE;
DROP USER PRY2205_EFT_CON CASCADE;

-- 2. ELIMINAR ROLES SI EXISTEN (opcional)
-- DROP ROLE PRY2205_ROL_D;
-- DROP ROLE PRY2205_ROL_C;

-- 3. CREAR USUARIOS NUEVOS (Oracle Cloud)
CREATE USER PRY2205_EFT IDENTIFIED BY "Temporal123ABC"
DEFAULT TABLESPACE DATA
TEMPORARY TABLESPACE TEMP
QUOTA 10M ON DATA;

CREATE USER PRY2205_EFT_DES IDENTIFIED BY "Desarrollo123DE"
DEFAULT TABLESPACE DATA
TEMPORARY TABLESPACE TEMP
QUOTA 10M ON DATA;

CREATE USER PRY2205_EFT_CON IDENTIFIED BY "Consulta123FGH"
DEFAULT TABLESPACE DATA
TEMPORARY TABLESPACE TEMP
QUOTA 10M ON DATA;

-- 4. OTORGAR PRIVILEGIOS BÁSICOS DE CONEXIÓN
GRANT CREATE SESSION TO PRY2205_EFT;
GRANT CREATE SESSION TO PRY2205_EFT_DES;
GRANT CREATE SESSION TO PRY2205_EFT_CON;

-- 5. PRIVILEGIOS ESPECIALES PARA PRY2205_EFT (OWNER)
GRANT CREATE TABLE, CREATE INDEX, CREATE VIEW, 
      CREATE SEQUENCE, CREATE SYNONYM, CREATE PUBLIC SYNONYM 
TO PRY2205_EFT;

-- 6. CREAR ROLES
CREATE ROLE PRY2205_ROL_D;
CREATE ROLE PRY2205_ROL_C;

-- 7. CONFIGURAR PRIVILEGIOS DE ROLES
GRANT CREATE VIEW TO PRY2205_ROL_D;  -- Solo para desarrollador

-- 8. ASIGNAR ROLES A USUARIOS
GRANT PRY2205_ROL_D TO PRY2205_EFT_DES;
GRANT PRY2205_ROL_C TO PRY2205_EFT_CON;

-- 9. VERIFICAR CREACIÓN
SELECT username, account_status, default_tablespace, created 
FROM dba_users 
WHERE username LIKE 'PRY2205%'
ORDER BY username;

-- Paso 2: EJECUTAR EL SCRIPT QUE CREA Y POBLA TABLAS

-- Paso 3: COMPLETAR LA ESTRATEGIA DE SEGURIDAD

-- Volver a conectarse como SYS/SYSTEM
-- 1. Otorgar privilegios adicionales a PRY2205_EFT
GRANT CREATE TABLE, CREATE INDEX, CREATE VIEW, 
      CREATE SEQUENCE, CREATE SYNONYM TO PRY2205_EFT;

-- 2. Crear roles
CREATE ROLE PRY2205_ROL_D;
CREATE ROLE PRY2205_ROL_C;

-- 3. Otorgar privilegios a roles
GRANT CREATE VIEW, CREATE PROFILE, CREATE USER TO PRY2205_ROL_D;

-- 4. Asignar roles
GRANT PRY2205_ROL_D TO PRY2205_EFT_DES;
GRANT PRY2205_ROL_C TO PRY2205_EFT_CON;

-- Paso 4: CREAR SINÓNIMOS Y OTORGAR PERMISOS ESPECÍFICOS

-- Conectado como PRY2205_EFT
CREATE PUBLIC SYNONYM clientes FOR CLIENTE;
CREATE PUBLIC SYNONYM asesorias FOR ASESORIA;
CREATE PUBLIC SYNONYM profesionales FOR PROFESIONAL;
CREATE PUBLIC SYNONYM pagos FOR PAGO;
CREATE PUBLIC SYNONYM contratos FOR CONTRATO;
-- Agregar más según las tablas del modelo

-- Verificar sinónimos creados:
SELECT synonym_name, table_name FROM user_synonyms;








-- Caso 2: Creación de Informe:

PASO 0: Verificar Estructura de Tablas (como PRY2205_EFT_DES)
sql
-- Conéctate como PRY2205_EFT_DES con contraseña "Desarrollo123DE"
-- Verificar tablas disponibles
SELECT table_name FROM user_tables;
SELECT * FROM cat;  -- Ver todos los objetos

-- Ver estructura de tablas clave (usando sinónimos)
DESC profesionales;
DESC contratos;
DESC isapres;  -- Asumiendo que existe esta tabla
DESC cartola_profesionales;  -- Tabla destino (debe existir)

-- Conéctate como ADMIN y ejecuta:
CREATE PUBLIC SYNONYM isapres FOR ADMIN.ISAPRE;
-- Verificar:
SELECT * FROM dba_synonyms WHERE synonym_name = 'ISAPRES';


-- Primero crear la tabla destino si no existe
CREATE TABLE cartola_profesionales (
    rut_profesional VARCHAR2(12),
    nombre_completo VARCHAR2(100),
    profesion VARCHAR2(50),
    sueldo_base NUMBER,
    nombre_isapre VARCHAR2(50),
    porcentaje_comision NUMBER(5,2),
    valor_comision NUMBER,
    porcentaje_honorarios NUMBER(5,2),
    valor_honorarios NUMBER,
    bono_movilizacion NUMBER,
    total_pagar NUMBER,
    fecha_generacion DATE DEFAULT SYSDATE
);
PASO 2: Construir la Sentencia SQL Completa
sql
-- Esta es la consulta principal que INSERTA en CARTOLA_PROFESIONALES
INSERT INTO cartola_profesionales (
    rut_profesional,
    nombre_completo,
    profesion,
    sueldo_base,
    nombre_isapre,
    porcentaje_comision,
    valor_comision,
    porcentaje_honorarios,
    valor_honorarios,
    bono_movilizacion,
    total_pagar
)

SELECT
     -- 1. Datos básicos del profesional  
    p.rut                                                               AS rut_profesional,
    p.nombre || ' ' || p.apellido                                       AS nombre_completo,
    pr.nombre                                                           AS profesion,  
    p.sueldo_base,
    i.nombre                                                            AS nombre_isapre,
    
     -- 2. Comisión (manejo de nulos con NVL)
    NVL(p.porcentaje_comision, 0)                                       AS porcentaje_comision,
    ROUND(NVL(p.sueldo_base * p.porcentaje_comision / 100, 0))          AS valor_comision,
    
    -- 3. Honorarios (usando CASE para rangos)
    CASE 
        WHEN p.sueldo_base <= 1000000 THEN 5
        WHEN p.sueldo_base <= 2000000 THEN 7
        WHEN p.sueldo_base <= 3000000 THEN 10
        WHEN p.sueldo_base <= 5000000 THEN 12
        ELSE 15
    END                                                                 AS porcentaje_honorarios,
    
    
     ROUND(
        CASE 
            WHEN p.sueldo_base <= 1000000 THEN p.sueldo_base * 0.05
            WHEN p.sueldo_base <= 2000000 THEN p.sueldo_base * 0.07
            WHEN p.sueldo_base <= 3000000 THEN p.sueldo_base * 0.10
            WHEN p.sueldo_base <= 5000000 THEN p.sueldo_base * 0.12
            ELSE p.sueldo_base * 0.15
        END
    )                                                                   AS valor_honorarios,
    
    -- 4. Bono de movilización (según tipo de contrato)
    CASE tc.nombre  -- Cambiado: viene de tabla TIPO_CONTRATO
        WHEN 'Indefinido Jornada Completa' THEN 150000
        WHEN 'Indefinido Jornada Parcial' THEN 120000
        WHEN 'Plazo fijo' THEN 60000
        WHEN 'Honorarios' THEN 50000
        ELSE 0
    END AS bono_movilizacion,
    
    -- 5. Total a pagar (SUMA de todos los componentes)
    ROUND(
        p.sueldo_base +
        NVL(p.sueldo_base * p.porcentaje_comision / 100, 0) +
        CASE 
            WHEN p.sueldo_base <= 1000000 THEN p.sueldo_base * 0.05
            WHEN p.sueldo_base <= 2000000 THEN p.sueldo_base * 0.07
            WHEN p.sueldo_base <= 3000000 THEN p.sueldo_base * 0.10
            WHEN p.sueldo_base <= 5000000 THEN p.sueldo_base * 0.12
            ELSE p.sueldo_base * 0.15
        END +
        CASE tc.nombre
            WHEN 'Indefinido Jornada Completa' THEN 150000
            WHEN 'Indefinido Jornada Parcial' THEN 120000
            WHEN 'Plazo fijo' THEN 60000
            WHEN 'Honorarios' THEN 50000
            ELSE 0
        END
    ) AS total_pagar
    
FROM profesionales p  -- Sinónimo que apunta a ADMIN.PROFESIONAL
JOIN contrato c ON p.id_profesional = c.id_profesional  -- Tabla real: CONTRATO
JOIN tipo_contrato tc ON c.id_tipo_contrato = tc.id_tipo_contrato  -- Nueva tabla
LEFT JOIN isapres i ON p.id_isapre = i.id_isapre  -- Sinónimo que crearemos
LEFT JOIN profesion pr ON p.id_profesion = pr.id_profesion  -- Tabla PROFESION

-- Ordenamiento requerido
ORDER BY 
    pr.nombre,  -- profesion desde tabla PROFESION
    p.sueldo_base DESC,
    NVL(p.porcentaje_comision, 0) DESC,
    p.rut;


--PASO 3: Verificar y Mostrar los Resultados

-- Verificar cuántos registros se insertaron
SELECT COUNT(*) AS total_registros FROM cartola_profesionales;

-- Mostrar el informe completo 
SELECT 
    rut_profesional                                               AS "RUT",
    nombre_completo                                               AS "NOMBRE COMPLETO",
    profesion                                                     AS "PROFESIÓN",
    TO_CHAR(sueldo_base, 'L999G999G999')                          AS "SUELDO BASE",
    nombre_isapre                                                 AS "ISAPRE",
    porcentaje_comision || '%'                                    AS "% COMISIÓN",
    TO_CHAR(valor_comision, 'L999G999G999')                       AS "VALOR COMISIÓN",
    porcentaje_honorarios || '%'                                  AS "% HONORARIOS",
    TO_CHAR(valor_honorarios, 'L999G999G999')                     AS "VALOR HONORARIOS",
    TO_CHAR(bono_movilizacion, 'L999G999G999')                    AS "BONO MOVILIZACIÓN",
    TO_CHAR(total_pagar, 'L999G999G999')                          AS "TOTAL A PAGAR"
FROM cartola_profesionales
ORDER BY 
    profesion,
    sueldo_base DESC,
    porcentaje_comision DESC,
    rut_profesional;

PASO 4: Otorgar Permisos a PRY2205_EFT_CON (Requerimiento de Seguridad)
sql
-- Como PRY2205_EFT_DES, otorgar permisos de SELECT
GRANT SELECT ON cartola_profesionales TO PRY2205_EFT_CON;

-- También puedes crear un sinónimo público para facilitar el acceso
CREATE PUBLIC SYNONYM cartola_profesionales FOR cartola_profesionales;
-- Nota: En Oracle Cloud, PRY2205_EFT_DES no puede crear sinónimos públicos
-- En ese caso, ADMIN debe crear el sinónimo público
PASO 5: Probar Acceso desde PRY2205_EFT_CON
sql
-- Conéctate como PRY2205_EFT_CON ("Consulta123FGH")
-- Verificar acceso
SELECT * FROM PRY2205_EFT_DES.cartola_profesionales WHERE ROWNUM <= 5;

-- O usando el sinónimo (si se creó)
SELECT COUNT(*) FROM cartola_profesionales;
🔧 AJUSTES NECESARIOS (según tu modelo real):
Debes verificar los nombres exactos de columnas en tus tablas:

sql
-- Consulta para ver estructura de tablas clave
SELECT column_name, data_type, nullable 
FROM user_tab_columns 
WHERE table_name IN ('PROFESIONALES', 'CONTRATOS', 'ISAPRES')
ORDER BY table_name, column_id;








-- Caso 3: Optimización de sentencias SQL

-- Caso 3.1: Creación de Vista
PASO 1: Conectarse como PRY2205_EFT
sql
-- Usuario: PRY2205_EFT
-- Contraseña: MontenegroSA@2024
PASO 2: Crear la Vista
sql
CREATE OR REPLACE VIEW VW_EMPRESAS_ASESORADAS AS
SELECT
    -- 1. DATOS BÁSICOS DE LA EMPRESA
    e.rut AS "RUT_EMPRESA",
    e.nombre AS "NOMBRE_EMPRESA",
    
    -- 2. AÑOS DE ANTIGÜEDAD (desde fecha_inicio_actividades)
    TRUNC(MONTHS_BETWEEN(SYSDATE, e.fecha_inicio_actividades) / 12) AS "AÑOS_ANTIGÜEDAD",
    
    -- 3. IVA DECLARADO (usando NVL por si es NULL)
    NVL(e.iva_declarado, 0) AS "IVA_DECLARADO",
    
    -- 4. TOTAL DE ASESORÍAS EN EL AÑO ANTERIOR
    COUNT(DISTINCT a.id_asesoria) AS "TOTAL_ASESORIAS_ANIO_ANT",
    
    -- 5. PROMEDIO MENSUAL DE ASESORÍAS (total / 12)
    ROUND(COUNT(DISTINCT a.id_asesoria) / 12, 2) AS "PROMEDIO_MENSUAL_ASESORIAS",
    
    -- 6. DEVOLUCIÓN ESTIMADA DE IVA (IVA * promedio / 100)
    ROUND(NVL(e.iva_declarado, 0) * (COUNT(DISTINCT a.id_asesoria) / 12) / 100, 0) AS "DEVOLUCION_IVA_ESTIMADA",
    
    -- 7. CLASIFICACIÓN DEL CLIENTE según promedio anual
    CASE 
        WHEN ROUND(COUNT(DISTINCT a.id_asesoria) / 12, 2) > 5 THEN 'CLIENTE PREMIUM'
        WHEN ROUND(COUNT(DISTINCT a.id_asesoria) / 12, 2) >= 3 THEN 'CLIENTE'
        ELSE 'CLIENTE POCO CONCURRIDO'
    END AS "TIPO_CLIENTE",
    
    -- 8. PROMOCIONES según cantidad de asesorías y tipo
    CASE 
        -- CLIENTE PREMIUM
        WHEN ROUND(COUNT(DISTINCT a.id_asesoria) / 12, 2) > 5 THEN
            CASE 
                WHEN COUNT(DISTINCT a.id_asesoria) >= 7 THEN '1 ASESORÍA GRATIS'
                ELSE '1 ASESORÍA 40% DE DESCUENTO'
            END
        -- CLIENTE NORMAL
        WHEN ROUND(COUNT(DISTINCT a.id_asesoria) / 12, 2) >= 3 THEN
            CASE 
                WHEN COUNT(DISTINCT a.id_asesoria) = 5 THEN '1 ASESORÍA 30% DE DESCUENTO'
                ELSE '1 ASESORÍA 20% DE DESCUENTO'
            END
        -- CLIENTE POCO CONCURRIDO
        ELSE 'CAPTAR CLIENTE'
    END AS "PROMOCION_RECOMENDADA",
    
    -- 9. AÑO DE CONSULTA (para referencia)
    EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -12)) AS "AÑO_CONSULTADO"

FROM empresas e
LEFT JOIN asesorias a ON e.id_empresa = a.id_empresa
    -- Solo asesorías terminadas el año anterior al actual
    AND EXTRACT(YEAR FROM a.fecha_termino) = EXTRACT(YEAR FROM SYSDATE) - 1
    AND a.estado = 'TERMINADA'  -- Asumiendo que hay columna estado

WHERE e.fecha_inicio_actividades IS NOT NULL

GROUP BY 
    e.rut, 
    e.nombre, 
    e.fecha_inicio_actividades,
    e.iva_declarado

HAVING COUNT(DISTINCT a.id_asesoria) >= 0  -- Incluye todas las empresas, incluso sin asesorías

ORDER BY e.nombre ASC;
PASO 3: Verificar la Vista
sql
-- Verificar que la vista se creó
SELECT object_name, object_type, status 
FROM user_objects 
WHERE object_name = 'VW_EMPRESAS_ASESORADAS';

-- Consultar algunos datos de la vista
SELECT * FROM VW_EMPRESAS_ASESORADAS WHERE ROWNUM <= 10;

-- Verificar estructura
DESC VW_EMPRESAS_ASESORADAS;
PASO 4: Otorgar Permisos a PRY2205_EFT_CON
sql
-- Otorgar permiso SELECT sobre la vista
GRANT SELECT ON VW_EMPRESAS_ASESORADAS TO PRY2205_EFT_CON;

-- Opcional: Crear sinónimo público (como ADMIN si es necesario)
-- CREATE PUBLIC SYNONYM VW_EMPRESAS_ASESORADAS FOR PRY2205_EFT.VW_EMPRESAS_ASESORADAS;



-- Caso 3.2: Creación de Índices

-- PASO 5: Analizar Plan de Ejecución Actual
sql
-- 1. Verificar estadísticas de tablas
EXEC DBMS_STATS.GATHER_TABLE_STATS('PRY2205_EFT', 'EMPRESAS');
EXEC DBMS_STATS.GATHER_TABLE_STATS('PRY2205_EFT', 'ASESORIAS');

-- 2. Obtener plan de ejecución de la vista
EXPLAIN PLAN FOR
SELECT * FROM VW_EMPRESAS_ASESORADAS;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- PASO 6: Crear Índices Estratégicos
sql
-- ÍNDICE 1: Para filtro por año en ASESORIAS (fecha_termino + estado)
CREATE INDEX IDX_ASESORIAS_FECHA_ESTADO ON ASESORIAS (
    EXTRACT(YEAR FROM fecha_termino),
    estado
) COMPUTE STATISTICS;

-- ÍNDICE 2: Para JOIN entre EMPRESAS y ASESORIAS
CREATE INDEX IDX_ASESORIAS_EMPRESA ON ASESORIAS(id_empresa) COMPUTE STATISTICS;

-- ÍNDICE 3: Para ORDER BY en la vista (nombre de empresa)
CREATE INDEX IDX_EMPRESAS_NOMBRE ON EMPRESAS(nombre) COMPUTE STATISTICS;

-- ÍNDICE 4: Para filtro de fecha_inicio_actividades (no nula)
CREATE INDEX IDX_EMPRESAS_FECHA_INICIO ON EMPRESAS(fecha_inicio_actividades)
WHERE fecha_inicio_actividades IS NOT NULL COMPUTE STATISTICS;

--PASO 7: Verificar Índices Creados
sql
-- Verificar todos los índices
SELECT index_name, table_name, uniqueness, status
FROM user_indexes
WHERE table_name IN ('EMPRESAS', 'ASESORIAS')
ORDER BY table_name, index_name;

-- Verificar columnas de cada índice
SELECT 
    i.index_name,
    i.table_name,
    ic.column_name,
    ic.column_position
FROM user_indexes i
JOIN user_ind_columns ic ON i.index_name = ic.index_name
WHERE i.table_name IN ('EMPRESAS', 'ASESORIAS')
ORDER BY i.index_name, ic.column_position;
PASO 8: Comparar Plan de Ejecución Después de Índices
sql
-- Limpiar cache para prueba justa
ALTER SYSTEM FLUSH BUFFER_CACHE;
ALTER SYSTEM FLUSH SHARED_POOL;

-- Nuevo plan de ejecución
EXPLAIN PLAN FOR
SELECT * FROM VW_EMPRESAS_ASESORADAS;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
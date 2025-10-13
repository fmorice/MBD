-- ===============================================
-- EVALUACIÓN FINAL TRANSVERSAL - SEMANA 9
-- CRISTALERÍA ANDINA S.A.
-- PRY2204 - Bases de Datos
-- ===============================================

-- ===============================================
-- CREACIÓN DE USUARIO
-- ===============================================

/* Creación de usuario si estás trabajando con BD Oracle XE */
/* este ocupamos */
ALTER SESSION SET "_Oracle_Script"=TRUE;

CREATE USER PRY2204_S9 
IDENTIFIED BY "PRY2204.semana_9" 
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION TO PRY2204_S9;

GRANT RESOURCE TO PRY2204_S9;

ALTER USER PRY2204_S9 DEFAULT ROLE RESOURCE; /* este ocupamos */




/* Creación de usuario si está trabajando con BD Oracle Cloud */
/* No ocupamos */
CREATE USER PRY2204_S9 
IDENTIFIED BY "PRY2204.semana_9"
DEFAULT TABLESPACE DATA
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON DATA;

GRANT CREATE SESSION TO PRY2204_S9;

GRANT RESOURCE TO PRY2204_S9;

ALTER USER PRY2204_S9 DEFAULT ROLE RESOURCE;/* No ocupamos */

-- ===============================================
-- FASE 3 - SCRIPT SQL
-- Creación de tablas y datos de ejemplo

-- -----------------------------------------------
-- 1. TABLA REGION (con secuencia)
-- -----------------------------------------------

-- Crear secuencia para REGION
CREATE SEQUENCE seq_region
START WITH 1
INCREMENT BY 1;

-- Crear tabla REGION
CREATE TABLE REGION (
    id_region NUMBER PRIMARY KEY,
    nombre_region VARCHAR2(50) NOT NULL,
    codigo_region CHAR(5) NOT NULL
);

-- -----------------------------------------------
-- 2. TABLA COMUNA (con IDENTITY - auto incremento)
-- -----------------------------------------------

CREATE TABLE COMUNA (
    id_comuna NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_comuna VARCHAR2(50) NOT NULL,
    id_region NUMBER NOT NULL,
    FOREIGN KEY (id_region) REFERENCES REGION(id_region)
);

-- -----------------------------------------------
-- 3. TABLA PLANTA
-- -----------------------------------------------

CREATE TABLE PLANTA (
    id_planta NUMBER PRIMARY KEY,
    nombre_planta VARCHAR2(50) NOT NULL,
    id_comuna NUMBER NOT NULL,
    FOREIGN KEY (id_comuna) REFERENCES COMUNA(id_comuna)
);

-- -----------------------------------------------
-- 4. TABLA EMPLEADO
-- -----------------------------------------------

CREATE TABLE EMPLEADO (
    id_empleado NUMBER PRIMARY KEY,
    nombre_empleado VARCHAR2(100) NOT NULL,
    id_planta NUMBER NOT NULL,
    FOREIGN KEY (id_planta) REFERENCES PLANTA(id_planta)
);

-- -----------------------------------------------
-- 5. TABLA TIPO_MAQUINA
-- -----------------------------------------------

CREATE TABLE TIPO_MAQUINA (
    id_tipo_maquina NUMBER PRIMARY KEY,
    nombre_tipo VARCHAR2(50) NOT NULL,
    descripcion VARCHAR2(100)
);

-- -----------------------------------------------
-- 6. TABLA MAQUINA
-- -----------------------------------------------

CREATE TABLE MAQUINA (
    id_maquina NUMBER PRIMARY KEY,
    nombre_maquina VARCHAR2(50) NOT NULL,
    id_tipo_maquina NUMBER NOT NULL,
    FOREIGN KEY (id_tipo_maquina) REFERENCES TIPO_MAQUINA(id_tipo_maquina)
);

-- -----------------------------------------------
-- 7. TABLA TURNO
-- -----------------------------------------------

CREATE TABLE TURNO (
    id_turno NUMBER PRIMARY KEY,
    nombre_turno VARCHAR2(30) NOT NULL,
    hora_inicio VARCHAR2(5) NOT NULL,
    hora_fin VARCHAR2(5) NOT NULL
);

-- -----------------------------------------------
-- 8. TABLA ORDEN_MANTENCION
-- -----------------------------------------------

CREATE TABLE ORDEN_MANTENCION (
    id_orden NUMBER PRIMARY KEY,
    fecha_orden DATE NOT NULL,
    id_maquina NUMBER NOT NULL,
    FOREIGN KEY (id_maquina) REFERENCES MAQUINA(id_maquina)
);

-- -----------------------------------------------
-- 9. TABLA ASIGNACION_TURNO
-- -----------------------------------------------

CREATE TABLE ASIGNACION_TURNO (
    id_asignacion NUMBER PRIMARY KEY,
    id_empleado NUMBER NOT NULL,
    id_turno NUMBER NOT NULL,
    FOREIGN KEY (id_empleado) REFERENCES EMPLEADO(id_empleado),
    FOREIGN KEY (id_turno) REFERENCES TURNO(id_turno)
);

-- ===============================================
-- INSERCIÓN DE DATOS DE EJEMPLO
-- ===============================================

-- -----------------------------------------------
-- Datos para REGION (usando secuencia)
-- -----------------------------------------------

INSERT INTO REGION (id_region, nombre_region, codigo_region) 
VALUES (seq_region.NEXTVAL, 'Metropolitana', 'RM');

INSERT INTO REGION (id_region, nombre_region, codigo_region) 
VALUES (seq_region.NEXTVAL, 'Valparaíso', 'V');

INSERT INTO REGION (id_region, nombre_region, codigo_region) 
VALUES (seq_region.NEXTVAL, 'Biobío', 'VIII');

-- -----------------------------------------------
-- Datos para COMUNA (con IDENTITY automático)
-- -----------------------------------------------

INSERT INTO COMUNA (nombre_comuna, id_region) VALUES ('Santiago', 1);
INSERT INTO COMUNA (nombre_comuna, id_region) VALUES ('Las Condes', 2);
INSERT INTO COMUNA (nombre_comuna, id_region) VALUES ('Valparaíso', 3);

-- -----------------------------------------------
-- Datos para PLANTA
-- -----------------------------------------------

INSERT INTO PLANTA (id_planta, nombre_planta, id_comuna) 
VALUES (1, 'Planta Central Santiago', 1);

INSERT INTO PLANTA (id_planta, nombre_planta, id_comuna) 
VALUES (2, 'Planta Las Condes', 2);

INSERT INTO PLANTA (id_planta, nombre_planta, id_comuna) 
VALUES (3, 'Planta Valparaíso', 3);

-- -----------------------------------------------
-- Datos para TURNO
-- -----------------------------------------------

INSERT INTO TURNO (id_turno, nombre_turno, hora_inicio, hora_fin) 
VALUES (1, 'Mañana', '07:00', '15:00');

INSERT INTO TURNO (id_turno, nombre_turno, hora_inicio, hora_fin) 
VALUES (2, 'Tarde', '15:00', '23:00');

INSERT INTO TURNO (id_turno, nombre_turno, hora_inicio, hora_fin) 
VALUES (3, 'Noche', '23:00', '07:00');

INSERT INTO TURNO (id_turno, nombre_turno, hora_inicio, hora_fin) 
VALUES (4, 'Madrugada', '06:00', '14:00');

INSERT INTO TURNO (id_turno, nombre_turno, hora_inicio, hora_fin) 
VALUES (5, 'Nocturno', '22:00', '06:00');

-- ===============================================
-- FASE 4 - CONSULTAS SELECT
-- ===============================================

-- -----------------------------------------------
-- Consulta 1: Turnos con hora de inicio > '20:00'
-- -----------------------------------------------

SELECT 
    nombre_turno AS TURNO,
    hora_inicio AS HORA_INICIO,
    hora_fin AS HORA_FIN
FROM TURNO
WHERE hora_inicio > '20:00'
ORDER BY hora_inicio;

-- -----------------------------------------------
-- Consulta 2: Turnos con hora de inicio entre '06:00' y '14:59'
-- -----------------------------------------------

SELECT 
    nombre_turno AS TURNO,
    hora_inicio AS HORA_INICIO,
    hora_fin AS HORA_FIN
FROM TURNO
WHERE hora_inicio BETWEEN '06:00' AND '14:59'
ORDER BY hora_inicio;
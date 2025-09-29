-- ========================================
-- CREACIÓN DE USUARIO (ejecutar con SYS)
-- ========================================
CREATE USER PRY2204_S7 
IDENTIFIED BY "PRY2204.semana_7"
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON USERS;

-- Otorgar privilegios necesarios
GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER TO PRY2204_S7;
GRANT SELECT ANY TABLE TO PRY2204_S7;

-- ========================================
-- CONECTARSE COMO PRY2204_S7
-- sqlplus PRY2204_S7/PRY2204.semana_7@localhost:1531/XEPDB1
-- ========================================

-- ========================================
-- CREACIÓN DE SECUENCIAS
-- ========================================
CREATE SEQUENCE seq_region START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_comuna START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_compania START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_personal START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_genero START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_estado_civil START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_titulo START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_titulacion START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_idioma START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_dominio START WITH 1 INCREMENT BY 1;

-- ========================================
-- TABLAS MAESTRAS
-- ========================================

CREATE TABLE REGION (
    id_region NUMBER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL
);

CREATE TABLE COMUNA (
    id_comuna NUMBER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    id_region NUMBER NOT NULL,
    FOREIGN KEY (id_region) REFERENCES REGION(id_region)
);

CREATE TABLE COMPANIA (
    id_compania NUMBER PRIMARY KEY,
    nombre VARCHAR2(150) NOT NULL,
    direccion VARCHAR2(200),
    id_comuna NUMBER NOT NULL,
    FOREIGN KEY (id_comuna) REFERENCES COMUNA(id_comuna)
);

CREATE TABLE GENERO (
    id_genero NUMBER PRIMARY KEY,
    descripcion VARCHAR2(20) NOT NULL
);

CREATE TABLE ESTADO_CIVIL (
    id_estado_civil NUMBER PRIMARY KEY,
    descripcion VARCHAR2(50) NOT NULL
);

CREATE TABLE TITULO (
    id_titulo NUMBER PRIMARY KEY,
    nombre VARCHAR2(150) NOT NULL
);

CREATE TABLE TITULACION (
    id_titulacion NUMBER PRIMARY KEY,
    id_titulo NUMBER NOT NULL,
    institucion VARCHAR2(150),
    anio NUMBER,
    FOREIGN KEY (id_titulo) REFERENCES TITULO(id_titulo)
);

CREATE TABLE IDIOMA (
    id_idioma NUMBER PRIMARY KEY,
    nombre VARCHAR2(50) NOT NULL
);

CREATE TABLE DOMINIO (
    id_dominio NUMBER PRIMARY KEY,
    descripcion VARCHAR2(50) NOT NULL
);

-- ========================================
-- TABLAS DE RELACIÓN
-- ========================================

CREATE TABLE PERSONAL (
    id_personal NUMBER PRIMARY KEY,
    run VARCHAR2(20) UNIQUE NOT NULL,
    nombres VARCHAR2(100) NOT NULL,
    apellidos VARCHAR2(100) NOT NULL,
    email VARCHAR2(150),
    sueldo NUMBER(12,2),
    id_compania NUMBER NOT NULL,
    id_comuna NUMBER NOT NULL,
    id_genero NUMBER NOT NULL,
    id_estado_civil NUMBER NOT NULL,
    id_titulacion NUMBER,
    FOREIGN KEY (id_compania) REFERENCES COMPANIA(id_compania),
    FOREIGN KEY (id_comuna) REFERENCES COMUNA(id_comuna),
    FOREIGN KEY (id_genero) REFERENCES GENERO(id_genero),
    FOREIGN KEY (id_estado_civil) REFERENCES ESTADO_CIVIL(id_estado_civil),
    FOREIGN KEY (id_titulacion) REFERENCES TITULACION(id_titulacion)
);

CREATE TABLE PERSONAL_IDIOMA (
    id_personal NUMBER NOT NULL,
    id_idioma NUMBER NOT NULL,
    id_dominio NUMBER NOT NULL,
    PRIMARY KEY (id_personal, id_idioma),
    FOREIGN KEY (id_personal) REFERENCES PERSONAL(id_personal),
    FOREIGN KEY (id_idioma) REFERENCES IDIOMA(id_idioma),
    FOREIGN KEY (id_dominio) REFERENCES DOMINIO(id_dominio)
);

-- ========================================
-- INSERTS DE EJEMPLO
-- ========================================

-- Regiones
INSERT INTO REGION VALUES (seq_region.NEXTVAL, 'Metropolitana');
INSERT INTO REGION VALUES (seq_region.NEXTVAL, 'Valparaíso');

-- Comunas
INSERT INTO COMUNA VALUES (seq_comuna.NEXTVAL, 'Santiago Centro', 1);
INSERT INTO COMUNA VALUES (seq_comuna.NEXTVAL, 'Viña del Mar', 2);

-- Compañías
INSERT INTO COMPANIA VALUES (seq_compania.NEXTVAL, 'Holding Principal S.A.', 'Av. Providencia 1234', 1);
INSERT INTO COMPANIA VALUES (seq_compania.NEXTVAL, 'Servicios Secundarios Ltda.', 'Av. Libertad 567', 2);

-- Género
INSERT INTO GENERO VALUES (seq_genero.NEXTVAL, 'Masculino');
INSERT INTO GENERO VALUES (seq_genero.NEXTVAL, 'Femenino');

-- Estado civil
INSERT INTO ESTADO_CIVIL VALUES (seq_estado_civil.NEXTVAL, 'Soltero/a');
INSERT INTO ESTADO_CIVIL VALUES (seq_estado_civil.NEXTVAL, 'Casado/a');

-- Títulos
INSERT INTO TITULO VALUES (seq_titulo.NEXTVAL, 'Ingeniería Comercial');
INSERT INTO TITULO VALUES (seq_titulo.NEXTVAL, 'Ingeniería en Informática');

-- Titulación
INSERT INTO TITULACION VALUES (seq_titulacion.NEXTVAL, 1, 'Universidad de Chile', 2015);
INSERT INTO TITULACION VALUES (seq_titulacion.NEXTVAL, 2, 'UTFSM', 2018);

-- Idiomas
INSERT INTO IDIOMA VALUES (seq_idioma.NEXTVAL, 'Inglés');
INSERT INTO IDIOMA VALUES (seq_idioma.NEXTVAL, 'Portugués');

-- Dominios
INSERT INTO DOMINIO VALUES (seq_dominio.NEXTVAL, 'Básico');
INSERT INTO DOMINIO VALUES (seq_dominio.NEXTVAL, 'Avanzado');

-- Personal
INSERT INTO PERSONAL VALUES (seq_personal.NEXTVAL, '12345678-9', 'Juan', 'Pérez', 'juan.perez@email.com', 1200000, 1, 1, 1, 1, 1);
INSERT INTO PERSONAL VALUES (seq_personal.NEXTVAL, '98765432-1', 'María', 'González', 'maria.gonzalez@email.com', 1500000, 2, 2, 2, 2, 2);

-- Personal - Idioma
INSERT INTO PERSONAL_IDIOMA VALUES (1, 1, 2); -- Juan - Inglés avanzado
INSERT INTO PERSONAL_IDIOMA VALUES (2, 2, 1); -- María - Portugués básico

COMMIT;

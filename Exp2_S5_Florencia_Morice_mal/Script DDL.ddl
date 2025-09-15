-- Generado por Oracle SQL Developer Data Modeler 24.3.1.351.0831
--   en:        2025-09-14 23:47:55 CLST
--   sitio:      Oracle Database 11g
--   tipo:      Oracle Database 11g



-- predefined type, no DDL - MDSYS.SDO_GEOMETRY

-- predefined type, no DDL - XMLTYPE

CREATE TABLE AFP 
    ( 
     id_afp NUMBER  NOT NULL , 
     codigo VARCHAR2 (100)  NOT NULL , 
     nombre VARCHAR2 (100)  NOT NULL 
    ) 
;

-- Error - Unique Constraint AFP.AFP_codigo_UN doesn't have columns

CREATE TABLE ATENCION 
    ( 
     id_atencion   NUMBER  NOT NULL , 
     fecha_hora    TIMESTAMP  NOT NULL , 
     tipo_atencion VARCHAR2 (20)  NOT NULL , 
     PACIENTE_rut  VARCHAR2 (12)  NOT NULL , 
     MEDICO_rut    VARCHAR2 (12)  NOT NULL , 
     diagnostico   CLOB , 
     monto_pagado  NUMBER (10,2)  NOT NULL 
    ) 
;
CREATE INDEX idx_atencion_paciente ON ATENCION 
    ( 
     PACIENTE_rut ASC 
    ) 
;
CREATE INDEX idx_atencion_medico ON ATENCION 
    ( 
     MEDICO_rut ASC 
    ) 
;

ALTER TABLE ATENCION 
    ADD CONSTRAINT ck_atencion_tipo 
    CHECK (tipo_atencion IN ('general', 'urgencia', 'preventiva'))
;
ALTER TABLE ATENCION 
    ADD CONSTRAINT ATENCION_PK PRIMARY KEY ( id_atencion ) ;

CREATE TABLE COMUNA 
    ( 
     id_comuna NUMBER  NOT NULL , 
     nombre    VARCHAR2 (50)  NOT NULL , 
     REGION_id NUMBER  NOT NULL 
    ) 
;

ALTER TABLE COMUNA 
    ADD CONSTRAINT COMUNA_PK PRIMARY KEY ( id_comuna ) ;

CREATE TABLE ESPECIALIDAD 
    ( 
     id_especialidad NUMBER  NOT NULL , 
     nombre          VARCHAR2 (50)  NOT NULL , 
     descripcion     VARCHAR2 (200) 
    ) 
;

ALTER TABLE ESPECIALIDAD 
    ADD CONSTRAINT ESPECIALIDAD_PK PRIMARY KEY ( id_especialidad ) ;

ALTER TABLE ESPECIALIDAD 
    ADD CONSTRAINT ESPECIALIDAD_nombre_UN UNIQUE ( nombre ) ;

CREATE TABLE EXAMEN_LABORATORIO 
    ( 
     codigo                  VARCHAR2 (10)  NOT NULL , 
     nombre                  VARCHAR2 (100)  NOT NULL , 
     tipo_muestra            VARCHAR2 (50)  NOT NULL , 
     condiciones_preparacion VARCHAR2 (200) 
    ) 
;

ALTER TABLE EXAMEN_LABORATORIO 
    ADD CONSTRAINT EXAMEN_LABORATORIO_PK PRIMARY KEY ( codigo ) ;

CREATE TABLE INSTITUCION_SALUD 
    ( 
     id_tipo NUMBER  NOT NULL , 
     codigo  VARCHAR2 (10)  NOT NULL , 
     nombre  VARCHAR2 (100)  NOT NULL , 
     tipo    VARCHAR2 (10)  NOT NULL 
    ) 
;

ALTER TABLE INSTITUCION_SALUD 
    ADD CONSTRAINT ck_institucion_tipo 
    CHECK (tipo IN ('Fonasa', 'Isapre'))
;
ALTER TABLE INSTITUCION_SALUD 
    ADD CONSTRAINT INSTITUCION_SALUD_PK PRIMARY KEY ( id_tipo ) ;

ALTER TABLE INSTITUCION_SALUD 
    ADD CONSTRAINT INSTITUCION_SALUD_codigo_UN UNIQUE ( codigo ) ;

CREATE TABLE MEDICO 
    ( 
     rut                  VARCHAR2 (12)  NOT NULL , 
     nombre_completo      VARCHAR2 (100)  NOT NULL , 
     fecha_ingreso        DATE  NOT NULL , 
     ESPECIALIDAD_id      NUMBER  NOT NULL , 
     afp_id               NUMBER  NOT NULL , 
     INSTITUCION_SALUD_id NUMBER  NOT NULL , 
     MEDICO_rut           VARCHAR2 (12) 
    ) 
;
CREATE INDEX idx_medico_especialidad ON MEDICO 
    ( 
     ESPECIALIDAD_id ASC 
    ) 
;
CREATE INDEX idx_medico_afp ON MEDICO 
    ( 
     afp_id ASC 
    ) 
;
CREATE INDEX idx_medico_institucion ON MEDICO 
    ( 
     INSTITUCION_SALUD_id ASC 
    ) 
;

ALTER TABLE MEDICO 
    ADD CONSTRAINT MEDICO_PK PRIMARY KEY ( rut ) ;

CREATE TABLE PACIENTE 
    ( 
     rut              VARCHAR2 (12)  NOT NULL , 
     nombre_completo  VARCHAR2 (100)  NOT NULL , 
     sexo             CHAR (1)  NOT NULL , 
     fecha_nacimiento DATE  NOT NULL , 
     direccion        VARCHAR2 (200) , 
     COMUNA_id        NUMBER  NOT NULL , 
     tipo_usuario     VARCHAR2 (20)  NOT NULL 
    ) 
;
CREATE INDEX idx_paciente_comuna ON PACIENTE 
    ( 
     COMUNA_id ASC 
    ) 
;

ALTER TABLE PACIENTE 
    ADD CONSTRAINT ck_paciente_sexo 
    CHECK (sexo IN ('M', 'F', 'O'))
;


ALTER TABLE PACIENTE 
    ADD CONSTRAINT ck_paciente_tipo 
    CHECK (tipo_usuario IN ('estudiante', 'funcionario', 'externo'))
;
ALTER TABLE PACIENTE 
    ADD CONSTRAINT PACIENTE_PK PRIMARY KEY ( rut ) ;

CREATE TABLE PAGO 
    ( 
     id_pago     NUMBER  NOT NULL , 
     ATENCION_id NUMBER  NOT NULL , 
     monto       NUMBER (10,2)  NOT NULL , 
     tipo_pago   VARCHAR2 (20)  NOT NULL , 
     fecha_pago  TIMESTAMP  NOT NULL 
    ) 
;

ALTER TABLE PAGO 
    ADD CONSTRAINT ck_pago_tipo 
    CHECK (tipo_pago IN ('efectivo', 'tarjeta', 'convenio'))
;
ALTER TABLE PAGO 
    ADD CONSTRAINT PAGO_PK PRIMARY KEY ( id_pago ) ;

ALTER TABLE PAGO 
    ADD CONSTRAINT PAGO_atencion_id_UN UNIQUE ( ATENCION_id ) ;

CREATE TABLE REGION 
    ( 
     id_region NUMBER  NOT NULL , 
     nombre    VARCHAR2 (50)  NOT NULL 
    ) 
;

ALTER TABLE REGION 
    ADD CONSTRAINT REGION_PK PRIMARY KEY ( id_region ) ;

CREATE TABLE SOLICITUD_EXAMEN 
    ( 
     id_examen                 NUMBER  NOT NULL , 
     ATENCION_id               NUMBER  NOT NULL , 
     EXAMEN_LABORATORIO_codigo VARCHAR2 (10)  NOT NULL , 
     fecha_solicitud           DATE  NOT NULL , 
     fecha_resultado           DATE , 
     resultado                 CLOB 
    ) 
;
CREATE INDEX idx_solicitud_atencion ON SOLICITUD_EXAMEN 
    ( 
     ATENCION_id ASC 
    ) 
;
CREATE INDEX idx_solicitud_examen ON SOLICITUD_EXAMEN 
    ( 
     EXAMEN_LABORATORIO_codigo ASC 
    ) 
;

ALTER TABLE SOLICITUD_EXAMEN 
    ADD CONSTRAINT SOLICITUD_EXAMEN_PK PRIMARY KEY ( id_examen ) ;

ALTER TABLE ATENCION 
    ADD CONSTRAINT ATENCION_MEDICO_FK FOREIGN KEY 
    ( 
     MEDICO_rut
    ) 
    REFERENCES MEDICO 
    ( 
     rut
    ) 
;

ALTER TABLE ATENCION 
    ADD CONSTRAINT ATENCION_PACIENTE_FK FOREIGN KEY 
    ( 
     PACIENTE_rut
    ) 
    REFERENCES PACIENTE 
    ( 
     rut
    ) 
;

ALTER TABLE COMUNA 
    ADD CONSTRAINT COMUNA_REGION_FK FOREIGN KEY 
    ( 
     REGION_id
    ) 
    REFERENCES REGION 
    ( 
     id_region
    ) 
;

-- Error - Foreign Key MEDICO_AFP_FK has no columns

ALTER TABLE MEDICO 
    ADD CONSTRAINT MEDICO_ESPECIALIDAD_FK FOREIGN KEY 
    ( 
     ESPECIALIDAD_id
    ) 
    REFERENCES ESPECIALIDAD 
    ( 
     id_especialidad
    ) 
;

ALTER TABLE MEDICO 
    ADD CONSTRAINT MEDICO_INSTITUCION_SALUD_FK FOREIGN KEY 
    ( 
     INSTITUCION_SALUD_id
    ) 
    REFERENCES INSTITUCION_SALUD 
    ( 
     id_tipo
    ) 
;

ALTER TABLE MEDICO 
    ADD CONSTRAINT MEDICO_MEDICO_FK FOREIGN KEY 
    ( 
     MEDICO_rut
    ) 
    REFERENCES MEDICO 
    ( 
     rut
    ) 
;

ALTER TABLE PACIENTE 
    ADD CONSTRAINT PACIENTE_COMUNA_FK FOREIGN KEY 
    ( 
     COMUNA_id
    ) 
    REFERENCES COMUNA 
    ( 
     id_comuna
    ) 
;

ALTER TABLE PAGO 
    ADD CONSTRAINT PAGO_ATENCION_FK FOREIGN KEY 
    ( 
     ATENCION_id
    ) 
    REFERENCES ATENCION 
    ( 
     id_atencion
    ) 
;

ALTER TABLE SOLICITUD_EXAMEN 
    ADD CONSTRAINT SOLICITUD_EXAMEN_ATENCION_FK FOREIGN KEY 
    ( 
     ATENCION_id
    ) 
    REFERENCES ATENCION 
    ( 
     id_atencion
    ) 
;

--  ERROR: FK name length exceeds maximum allowed length(30) 
ALTER TABLE SOLICITUD_EXAMEN 
    ADD CONSTRAINT SOLICITUD_EXAMEN_EXAMEN_LABORATORIO_FK FOREIGN KEY 
    ( 
     EXAMEN_LABORATORIO_codigo
    ) 
    REFERENCES EXAMEN_LABORATORIO 
    ( 
     codigo
    ) 
;



-- Informe de Resumen de Oracle SQL Developer Data Modeler: 
-- 
-- CREATE TABLE                            11
-- CREATE INDEX                             8
-- ALTER TABLE                             28
-- CREATE VIEW                              0
-- ALTER VIEW                               0
-- CREATE PACKAGE                           0
-- CREATE PACKAGE BODY                      0
-- CREATE PROCEDURE                         0
-- CREATE FUNCTION                          0
-- CREATE TRIGGER                           0
-- ALTER TRIGGER                            0
-- CREATE COLLECTION TYPE                   0
-- CREATE STRUCTURED TYPE                   0
-- CREATE STRUCTURED TYPE BODY              0
-- CREATE CLUSTER                           0
-- CREATE CONTEXT                           0
-- CREATE DATABASE                          0
-- CREATE DIMENSION                         0
-- CREATE DIRECTORY                         0
-- CREATE DISK GROUP                        0
-- CREATE ROLE                              0
-- CREATE ROLLBACK SEGMENT                  0
-- CREATE SEQUENCE                          0
-- CREATE MATERIALIZED VIEW                 0
-- CREATE MATERIALIZED VIEW LOG             0
-- CREATE SYNONYM                           0
-- CREATE TABLESPACE                        0
-- CREATE USER                              0
-- 
-- DROP TABLESPACE                          0
-- DROP DATABASE                            0
-- 
-- REDACTION POLICY                         0
-- 
-- ORDS DROP SCHEMA                         0
-- ORDS ENABLE SCHEMA                       0
-- ORDS ENABLE OBJECT                       0
-- 
-- ERRORS                                   3
-- WARNINGS                                 0

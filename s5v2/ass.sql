-- CREACIÓN DE TABLESPACE Y USUARIO (OPCIONAL)
/*
CREATE TABLESPACE ts_centro_medico
DATAFILE 'ts_centro_medico.dbf'
SIZE 100M AUTOEXTEND ON;

CREATE USER centro_medico IDENTIFIED BY password
DEFAULT TABLESPACE ts_centro_medico
QUOTA UNLIMITED ON ts_centro_medico;

GRANT CONNECT, RESOURCE TO centro_medico;
*/

-- TABLA REGION
CREATE TABLE REGION (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR2(50) NOT NULL
);

-- TABLA COMUNA
CREATE TABLE COMUNA (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR2(50) NOT NULL,
    region_id NUMBER NOT NULL,
    CONSTRAINT fk_comuna_region FOREIGN KEY (region_id) REFERENCES REGION(id)
);

-- TABLA ESPECIALIDAD
CREATE TABLE ESPECIALIDAD (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR2(50) NOT NULL,
    descripcion VARCHAR2(200),
    CONSTRAINT uk_especialidad_nombre UNIQUE (nombre)
);

-- TABLA AFP
CREATE TABLE AFP (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR2(10) NOT NULL,
    nombre VARCHAR2(100) NOT NULL,
    CONSTRAINT uk_afp_codigo UNIQUE (codigo)
);

-- TABLA INSTITUCION_SALUD
CREATE TABLE INSTITUCION_SALUD (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR2(10) NOT NULL,
    nombre VARCHAR2(100) NOT NULL,
    tipo VARCHAR2(10) NOT NULL,
    CONSTRAINT uk_institucion_codigo UNIQUE (codigo),
    CONSTRAINT ck_institucion_tipo CHECK (tipo IN ('Fonasa', 'Isapre'))
);

-- TABLA PACIENTE
CREATE TABLE PACIENTE (
    rut VARCHAR2(12) PRIMARY KEY,
    nombre_completo VARCHAR2(100) NOT NULL,
    sexo CHAR(1) NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    direccion VARCHAR2(200),
    comuna_id NUMBER NOT NULL,
    tipo_usuario VARCHAR2(20) NOT NULL,
    CONSTRAINT fk_paciente_comuna FOREIGN KEY (comuna_id) REFERENCES COMUNA(id),
    CONSTRAINT ck_paciente_sexo CHECK (sexo IN ('M', 'F', 'O')),
    CONSTRAINT ck_paciente_tipo CHECK (tipo_usuario IN ('estudiante', 'funcionario', 'externo'))
);

-- TABLA MEDICO
CREATE TABLE MEDICO (
    rut VARCHAR2(12) PRIMARY KEY,
    nombre_completo VARCHAR2(100) NOT NULL,
    fecha_ingreso DATE NOT NULL,
    especialidad_id NUMBER NOT NULL,
    afp_id NUMBER NOT NULL,
    institucion_salud_id NUMBER NOT NULL,
    medico_supervisor_id VARCHAR2(12),
    CONSTRAINT fk_medico_especialidad FOREIGN KEY (especialidad_id) REFERENCES ESPECIALIDAD(id),
    CONSTRAINT fk_medico_afp FOREIGN KEY (afp_id) REFERENCES AFP(id),
    CONSTRAINT fk_medico_institucion FOREIGN KEY (institucion_salud_id) REFERENCES INSTITUCION_SALUD(id),
    CONSTRAINT fk_medico_supervisor FOREIGN KEY (medico_supervisor_id) REFERENCES MEDICO(rut)
);

-- TABLA ATENCION
CREATE TABLE ATENCION (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_hora TIMESTAMP NOT NULL,
    tipo_atencion VARCHAR2(20) NOT NULL,
    paciente_rut VARCHAR2(12) NOT NULL,
    medico_rut VARCHAR2(12) NOT NULL,
    diagnostico CLOB,
    monto_pagado NUMBER(10,2) NOT NULL,
    CONSTRAINT fk_atencion_paciente FOREIGN KEY (paciente_rut) REFERENCES PACIENTE(rut),
    CONSTRAINT fk_atencion_medico FOREIGN KEY (medico_rut) REFERENCES MEDICO(rut),
    CONSTRAINT ck_atencion_tipo CHECK (tipo_atencion IN ('general', 'urgencia', 'preventiva'))
);

-- TABLA PAGO
CREATE TABLE PAGO (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    atencion_id NUMBER NOT NULL,
    monto NUMBER(10,2) NOT NULL,
    tipo_pago VARCHAR2(20) NOT NULL,
    fecha_pago TIMESTAMP NOT NULL,
    CONSTRAINT fk_pago_atencion FOREIGN KEY (atencion_id) REFERENCES ATENCION(id),
    CONSTRAINT uk_pago_atencion UNIQUE (atencion_id),
    CONSTRAINT ck_pago_tipo CHECK (tipo_pago IN ('efectivo', 'tarjeta', 'convenio'))
);

-- TABLA EXAMEN_LABORATORIO
CREATE TABLE EXAMEN_LABORATORIO (
    codigo VARCHAR2(10) PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    tipo_muestra VARCHAR2(50) NOT NULL,
    condiciones_preparacion VARCHAR2(200)
);

-- TABLA SOLICITUD_EXAMEN
CREATE TABLE SOLICITUD_EXAMEN (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    atencion_id NUMBER NOT NULL,
    examen_codigo VARCHAR2(10) NOT NULL,
    fecha_solicitud DATE NOT NULL,
    fecha_resultado DATE,
    resultados CLOB,
    CONSTRAINT fk_solicitud_atencion FOREIGN KEY (atencion_id) REFERENCES ATENCION(id),
    CONSTRAINT fk_solicitud_examen FOREIGN KEY (examen_codigo) REFERENCES EXAMEN_LABORATORIO(codigo)
);

-- ÍNDICES PARA MEJORAR EL RENDIMIENTO
CREATE INDEX idx_paciente_comuna ON PACIENTE(comuna_id);
CREATE INDEX idx_medico_especialidad ON MEDICO(especialidad_id);
CREATE INDEX idx_medico_afp ON MEDICO(afp_id);
CREATE INDEX idx_medico_institucion ON MEDICO(institucion_salud_id);
CREATE INDEX idx_atencion_paciente ON ATENCION(paciente_rut);
CREATE INDEX idx_atencion_medico ON ATENCION(medico_rut);
CREATE INDEX idx_solicitud_atencion ON SOLICITUD_EXAMEN(atencion_id);
CREATE INDEX idx_solicitud_examen ON SOLICITUD_EXAMEN(examen_codigo);

-- INSERCIÓN DE DATOS DE EJEMPLO
INSERT INTO REGION (nombre) VALUES 
('Región Metropolitana');

INSERT INTO REGION (nombre) VALUES 
('Valparaíso');

INSERT INTO REGION (nombre) VALUES 
('O''Higgins');

INSERT INTO COMUNA (nombre, region_id) VALUES 
('Santiago', 1);

INSERT INTO COMUNA (nombre, region_id) VALUES 
('Providencia', 1);

INSERT INTO COMUNA (nombre, region_id) VALUES 
('Viña del Mar', 2);

INSERT INTO COMUNA (nombre, region_id) VALUES 
('Rancagua', 3);

INSERT INTO ESPECIALIDAD (nombre, descripcion) VALUES 
('Medicina General', 'Atención médica general');

INSERT INTO ESPECIALIDAD (nombre, descripcion) VALUES 
('Psicología', 'Salud mental');

INSERT INTO ESPECIALIDAD (nombre, descripcion) VALUES 
('Cardiología', 'Especialidad en corazón');

INSERT INTO AFP (codigo, nombre) VALUES 
('AFP1', 'Capital');

INSERT INTO AFP (codigo, nombre) VALUES 
('AFP2', 'Habitat');

INSERT INTO AFP (codigo, nombre) VALUES 
('AFP3', 'Modelo');

INSERT INTO INSTITUCION_SALUD (codigo, nombre, tipo) VALUES 
('FON01', 'Fonasa Central', 'Fonasa');

INSERT INTO INSTITUCION_SALUD (codigo, nombre, tipo) VALUES 
('ISA01', 'Isapre Banmédica', 'Isapre');

INSERT INTO INSTITUCION_SALUD (codigo, nombre, tipo) VALUES 
('ISA02', 'Isapre Colmena', 'Isapre');

INSERT INTO PACIENTE (rut, nombre_completo, sexo, fecha_nacimiento, direccion, comuna_id, tipo_usuario) VALUES 
('12345678-9', 'Juan Pérez González', 'M', DATE '1990-05-15', 'Av. Siempre Viva 123', 1, 'estudiante');

INSERT INTO PACIENTE (rut, nombre_completo, sexo, fecha_nacimiento, direccion, comuna_id, tipo_usuario) VALUES 
('98765432-1', 'María López Martínez', 'F', DATE '1985-08-20', 'Calle Falsa 456', 2, 'funcionario');

INSERT INTO MEDICO (rut, nombre_completo, fecha_ingreso, especialidad_id, afp_id, institucion_salud_id, medico_supervisor_id) VALUES 
('11111111-1', 'Dr. Carlos Rodríguez Silva', DATE '2020-03-10', 1, 1, 1, NULL);

INSERT INTO MEDICO (rut, nombre_completo, fecha_ingreso, especialidad_id, afp_id, institucion_salud_id, medico_supervisor_id) VALUES 
('22222222-2', 'Dra. Ana Fernández García', DATE '2018-06-15', 2, 2, 2, '11111111-1');

INSERT INTO ATENCION (fecha_hora, tipo_atencion, paciente_rut, medico_rut, diagnostico, monto_pagado) VALUES 
(TIMESTAMP '2024-01-15 10:30:00', 'general', '12345678-9', '11111111-1', 'Resfriado común', 25000);

INSERT INTO ATENCION (fecha_hora, tipo_atencion, paciente_rut, medico_rut, diagnostico, monto_pagado) VALUES 
(TIMESTAMP '2024-01-16 11:00:00', 'urgencia', '98765432-1', '22222222-2', 'Ansiedad leve', 35000);

INSERT INTO PAGO (atencion_id, monto, tipo_pago, fecha_pago) VALUES 
(1, 25000, 'efectivo', TIMESTAMP '2024-01-15 10:45:00');

INSERT INTO PAGO (atencion_id, monto, tipo_pago, fecha_pago) VALUES 
(2, 35000, 'tarjeta', TIMESTAMP '2024-01-16 11:30:00');

INSERT INTO EXAMEN_LABORATORIO (codigo, nombre, tipo_muestra, condiciones_preparacion) VALUES 
('HEMO01', 'Hemograma completo', 'Sangre', 'Ayuno de 8 horas');

INSERT INTO EXAMEN_LABORATORIO (codigo, nombre, tipo_muestra, condiciones_preparacion) VALUES 
('GLUC01', 'Glucosa en sangre', 'Sangre', 'Ayuno de 12 horas');

INSERT INTO SOLICITUD_EXAMEN (atencion_id, examen_codigo, fecha_solicitud, fecha_resultado, resultados) VALUES 
(1, 'HEMO01', DATE '2024-01-15', DATE '2024-01-16', 'Resultados dentro de parámetros normales');

INSERT INTO SOLICITUD_EXAMEN (atencion_id, examen_codigo, fecha_solicitud, fecha_resultado, resultados) VALUES 
(2, 'GLUC01', DATE '2024-01-16', DATE '2024-01-17', 'Niveles de glucosa normales');

COMMIT;

-- CONSULTAS DE VERIFICACIÓN
SELECT 'Regiones: ' || COUNT(*) FROM REGION
UNION ALL
SELECT 'Comunas: ' || COUNT(*) FROM COMUNA
UNION ALL
SELECT 'Pacientes: ' || COUNT(*) FROM PACIENTE
UNION ALL
SELECT 'Médicos: ' || COUNT(*) FROM MEDICO
UNION ALL
SELECT 'Atenciones: ' || COUNT(*) FROM ATENCION;
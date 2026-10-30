-- Limpiar si ya existía a medias y crear la base de datos
DROP DATABASE IF EXISTS ebike_ems;
CREATE DATABASE ebike_ems;
USE ebike_ems;

-- ==========================================
-- 1. MÓDULO: IDENTIDAD Y ACCESO
-- ==========================================
CREATE TABLE ROLES (
    id_rol INT AUTO_INCREMENT PRIMARY KEY,
    codigo_rol VARCHAR(30) UNIQUE NOT NULL,
    nombre_rol VARCHAR(60) NOT NULL,
    nivel_acceso TINYINT NOT NULL,
    descripcion VARCHAR(255)
);

CREATE TABLE PERMISOS (
    id_permiso INT AUTO_INCREMENT PRIMARY KEY,
    codigo_permiso VARCHAR(60) UNIQUE NOT NULL,
    modulo VARCHAR(60) NOT NULL,
    descripcion VARCHAR(255) NOT NULL
);

CREATE TABLE ROLES_PERMISOS (
    id_rol INT,
    id_permiso INT,
    PRIMARY KEY (id_rol, id_permiso),
    FOREIGN KEY (id_rol) REFERENCES ROLES(id_rol),
    FOREIGN KEY (id_permiso) REFERENCES PERMISOS(id_permiso)
);

CREATE TABLE USUARIOS (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    id_rol INT NOT NULL,
    uuid CHAR(36) UNIQUE NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    telefono VARCHAR(20),
    estado ENUM('activo', 'inactivo', 'suspendido') NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_rol) REFERENCES ROLES(id_rol)
);

CREATE TABLE CONFIGURACION_SISTEMA (
    clave VARCHAR(60) PRIMARY KEY,
    valor VARCHAR(255) NOT NULL,
    descripcion VARCHAR(255),
    id_usuario_modifica INT,
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario_modifica) REFERENCES USUARIOS(id_usuario)
);

CREATE TABLE AUDITORIA (
    id_auditoria BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT,
    tabla VARCHAR(60) NOT NULL,
    id_registro BIGINT NOT NULL,
    accion ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    detalle TEXT,
    fecha_evento TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario) REFERENCES USUARIOS(id_usuario)
);

-- ==========================================
-- 2. MÓDULO: FLOTA Y ESTACIONES
-- ==========================================
CREATE TABLE ESTACIONES (
    id_estacion INT AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    direccion VARCHAR(255),
    latitud DECIMAL(9, 6) NOT NULL,
    longitud DECIMAL(9, 6) NOT NULL,
    capacidad INT NOT NULL CHECK (capacidad > 0),
    estado ENUM('operativa', 'mantenimiento', 'inactiva') NOT NULL
);

CREATE TABLE BICICLETAS (
    id_bicicleta INT AUTO_INCREMENT PRIMARY KEY,
    id_estacion INT,
    codigo_qr VARCHAR(100) UNIQUE NOT NULL,
    num_serie VARCHAR(100) UNIQUE NOT NULL,
    modelo VARCHAR(100),
    estado ENUM('disponible', 'en_uso', 'mantenimiento', 'baja') NOT NULL,
    kilometraje DECIMAL(10, 2) NOT NULL DEFAULT 0,
    proximo_mantenimiento DATE,
    FOREIGN KEY (id_estacion) REFERENCES ESTACIONES(id_estacion)
);

-- ==========================================
-- 3. MÓDULO: ALQUILER Y PAGOS
-- ==========================================
CREATE TABLE TARIFAS (
    id_tarifa INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    tarifa_base DECIMAL(10, 2) NOT NULL,
    valor_minuto DECIMAL(10, 2) NOT NULL CHECK (valor_minuto > 0),
    vigente_desde DATE NOT NULL,
    vigente_hasta DATE,
    activa BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE ALQUILERES (
    id_alquiler INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    id_bicicleta INT NOT NULL,
    id_estacion_origen INT NOT NULL,
    id_estacion_destino INT,
    id_tarifa INT NOT NULL,
    uuid_alquiler CHAR(36) UNIQUE NOT NULL,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME,
    duracion_minutos INT GENERATED ALWAYS AS (TIMESTAMPDIFF(MINUTE, fecha_inicio, fecha_fin)) STORED,
    costo_total DECIMAL(10, 2),
    estado ENUM('activo', 'completado', 'cancelado', 'incidencia') NOT NULL,
    bicicleta_activa INT GENERATED ALWAYS AS (CASE WHEN estado = 'activo' THEN id_bicicleta ELSE NULL END) STORED UNIQUE,
    FOREIGN KEY (id_usuario) REFERENCES USUARIOS(id_usuario),
    FOREIGN KEY (id_bicicleta) REFERENCES BICICLETAS(id_bicicleta),
    FOREIGN KEY (id_estacion_origen) REFERENCES ESTACIONES(id_estacion),
    FOREIGN KEY (id_estacion_destino) REFERENCES ESTACIONES(id_estacion),
    FOREIGN KEY (id_tarifa) REFERENCES TARIFAS(id_tarifa),
    CHECK (fecha_fin > fecha_inicio) -- REGLA MOVIDA AL FINAL
);

CREATE TABLE METODOS_PAGO (
    id_metodo_pago INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    tipo ENUM('tarjeta_credito', 'tarjeta_debito', 'transferencia', 'billetera_digital') NOT NULL,
    token_hash VARCHAR(255) UNIQUE NOT NULL,
    ultimos_cuatro CHAR(4),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_usuario) REFERENCES USUARIOS(id_usuario)
);

CREATE TABLE TRANSACCIONES (
    id_transaccion INT AUTO_INCREMENT PRIMARY KEY,
    id_alquiler INT UNIQUE NOT NULL,
    id_metodo_pago INT NOT NULL,
    monto DECIMAL(10, 2) NOT NULL,
    estado_pago ENUM('pendiente', 'aprobado', 'rechazado', 'reembolsado') NOT NULL,
    referencia_ext VARCHAR(100),
    fecha_proceso DATETIME,
    FOREIGN KEY (id_alquiler) REFERENCES ALQUILERES(id_alquiler),
    FOREIGN KEY (id_metodo_pago) REFERENCES METODOS_PAGO(id_metodo_pago)
);

-- ==========================================
-- 4. MÓDULO: MANTENIMIENTO
-- ==========================================
CREATE TABLE MANTENIMIENTOS (
    id_mantenimiento INT AUTO_INCREMENT PRIMARY KEY,
    id_bicicleta INT NOT NULL,
    id_usuario INT NOT NULL,
    tipo ENUM('preventivo', 'correctivo') NOT NULL,
    descripcion TEXT,
    actividad_realizada TEXT,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME,
    costo DECIMAL(10, 2),
    estado ENUM('reportado', 'en_mantenimiento', 'finalizado') NOT NULL,
    FOREIGN KEY (id_bicicleta) REFERENCES BICICLETAS(id_bicicleta),
    FOREIGN KEY (id_usuario) REFERENCES USUARIOS(id_usuario),
    CHECK (fecha_fin >= fecha_inicio) -- REGLA MOVIDA AL FINAL
);

-- ==========================================
-- 5. MÓDULO: ENERGÍA
-- ==========================================
CREATE TABLE BATERIAS (
    id_bateria INT AUTO_INCREMENT PRIMARY KEY,
    id_bicicleta INT UNIQUE NOT NULL,
    codigo_bateria VARCHAR(100) UNIQUE NOT NULL,
    capacidad_wh DECIMAL(10, 2) NOT NULL,
    nivel_carga DECIMAL(5, 2) CHECK (nivel_carga BETWEEN 0 AND 100),
    temperatura DECIMAL(5, 2),
    estado ENUM('disponible', 'cargando', 'cargada', 'baja', 'averiada') NOT NULL,
    fecha_instalacion DATE,
    vida_util INT,
    FOREIGN KEY (id_bicicleta) REFERENCES BICICLETAS(id_bicicleta)
);

CREATE TABLE PROCESOS_CARGA (
    id_carga INT AUTO_INCREMENT PRIMARY KEY,
    id_bateria INT NOT NULL,
    id_estacion INT NOT NULL,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME,
    duracion_minutos INT GENERATED ALWAYS AS (TIMESTAMPDIFF(MINUTE, fecha_inicio, fecha_fin)) STORED,
    nivel_inicial DECIMAL(5, 2),
    nivel_final DECIMAL(5, 2),
    FOREIGN KEY (id_bateria) REFERENCES BATERIAS(id_bateria),
    FOREIGN KEY (id_estacion) REFERENCES ESTACIONES(id_estacion),
    CHECK (fecha_fin > fecha_inicio) -- REGLA MOVIDA AL FINAL
);

CREATE TABLE REGISTROS_ENERGIA (
    id_registro_energia INT AUTO_INCREMENT PRIMARY KEY,
    id_estacion INT NOT NULL,
    id_carga INT,
    tipo_operacion ENUM('carga_bateria', 'consumo_estacion') NOT NULL,
    cantidad_kwh DECIMAL(10, 3) NOT NULL,
    costo_kwh DECIMAL(10, 2) NOT NULL,
    total_costo DECIMAL(14, 2) GENERATED ALWAYS AS (cantidad_kwh * costo_kwh) STORED,
    fecha_registro DATETIME NOT NULL,
    descripcion VARCHAR(255),
    FOREIGN KEY (id_estacion) REFERENCES ESTACIONES(id_estacion),
    FOREIGN KEY (id_carga) REFERENCES PROCESOS_CARGA(id_carga)
);

CREATE TABLE ALERTAS_ENERGIA (
    id_alerta INT AUTO_INCREMENT PRIMARY KEY,
    id_bateria INT,
    id_estacion INT,
    id_usuario_atiende INT,
    tipo ENUM('carga_critica', 'condicion_anormal', 'requiere_revision') NOT NULL,
    mensaje VARCHAR(255) NOT NULL,
    estado ENUM('abierta', 'atendida') NOT NULL,
    fecha_generacion DATETIME NOT NULL,
    fecha_atencion DATETIME,
    FOREIGN KEY (id_bateria) REFERENCES BATERIAS(id_bateria),
    FOREIGN KEY (id_estacion) REFERENCES ESTACIONES(id_estacion),
    FOREIGN KEY (id_usuario_atiende) REFERENCES USUARIOS(id_usuario)
);
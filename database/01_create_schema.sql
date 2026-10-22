-- Esquema completo para una instalación nueva de la plataforma UTS.
-- Compatible con MariaDB 10.4 / MySQL 8.0. No inserta cuentas ni datos de demostración.
-- Ejecutar primero; después ejecutar database/02_insert_initial_data.sql.
-- Las migraciones de instalaciones anteriores se conservan en database/legacy/.

CREATE DATABASE IF NOT EXISTS proyectos_grado_uts
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE proyectos_grado_uts;

CREATE TABLE IF NOT EXISTS roles (
  id TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre VARCHAR(40) NOT NULL,
  descripcion VARCHAR(180) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_roles_nombre (nombre)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS programas_academicos (
  id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo VARCHAR(30) NOT NULL,
  nombre VARCHAR(160) NOT NULL,
  facultad VARCHAR(120) NULL,
  activo TINYINT(1) NOT NULL DEFAULT 1,
  creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_programas_codigo (codigo),
  UNIQUE KEY uq_programas_nombre (nombre)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS areas_tematicas (
  id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo VARCHAR(30) NOT NULL,
  nombre VARCHAR(90) NOT NULL,
  descripcion VARCHAR(240) NULL,
  activa TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uq_areas_codigo (codigo),
  UNIQUE KEY uq_areas_nombre (nombre)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS usuarios (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  correo VARCHAR(190) NOT NULL,
  nombre_completo VARCHAR(160) NOT NULL,
  hash_contrasena VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  salt_contrasena CHAR(32) CHARACTER SET ascii COLLATE ascii_bin NULL,
  estado ENUM('pendiente', 'activo', 'inactivo', 'bloqueado') NOT NULL DEFAULT 'pendiente',
  ultimo_acceso DATETIME NULL,
  creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_usuarios_correo (correo),
  KEY ix_usuarios_estado (estado)
) ENGINE=InnoDB;

ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS salt_contrasena CHAR(32) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER hash_contrasena;

DELIMITER //
CREATE OR REPLACE FUNCTION pg_password_digest(p_password VARCHAR(200), p_salt CHAR(32))
RETURNS CHAR(64) CHARACTER SET ascii
DETERMINISTIC
NO SQL
SQL SECURITY INVOKER
BEGIN
  DECLARE digest CHAR(64) CHARACTER SET ascii;
  DECLARE rounds INT UNSIGNED DEFAULT 0;
  SET digest = SHA2(CONCAT(p_salt, ':', p_password), 256);
  WHILE rounds < 119999 DO
    SET digest = SHA2(CONCAT(p_salt, ':', p_password, ':', digest), 256);
    SET rounds = rounds + 1;
  END WHILE;
  RETURN digest;
END//
DELIMITER ;

CREATE TABLE IF NOT EXISTS usuario_roles (
  usuario_id BIGINT UNSIGNED NOT NULL,
  rol_id TINYINT UNSIGNED NOT NULL,
  asignado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (usuario_id, rol_id),
  CONSTRAINT fk_usuario_roles_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios (id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_usuario_roles_rol FOREIGN KEY (rol_id)
    REFERENCES roles (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS estudiantes (
  usuario_id BIGINT UNSIGNED NOT NULL,
  codigo_estudiantil VARCHAR(40) NOT NULL,
  programa_id SMALLINT UNSIGNED NOT NULL,
  semestre TINYINT UNSIGNED NULL,
  fecha_ingreso DATE NULL,
  PRIMARY KEY (usuario_id),
  UNIQUE KEY uq_estudiantes_codigo (codigo_estudiantil),
  KEY ix_estudiantes_programa (programa_id),
  CONSTRAINT fk_estudiantes_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios (id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_estudiantes_programa FOREIGN KEY (programa_id)
    REFERENCES programas_academicos (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS docentes (
  usuario_id BIGINT UNSIGNED NOT NULL,
  departamento VARCHAR(120) NULL,
  perfil_profesional TEXT NULL,
  PRIMARY KEY (usuario_id),
  CONSTRAINT fk_docentes_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ideas (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo VARCHAR(24) NOT NULL,
  titulo VARCHAR(180) NOT NULL,
  problema TEXT NOT NULL,
  descripcion TEXT NOT NULL,
  objetivos TEXT NULL,
  recursos_tecnologias TEXT NULL,
  beneficiarios VARCHAR(500) NULL,
  tipo ENUM('institucional', 'estudiantil') NOT NULL,
  estado ENUM(
    'borrador',
    'pendiente_revision',
    'en_revision',
    'requiere_ajustes',
    'aprobada',
    'rechazada',
    'archivada'
  ) NOT NULL DEFAULT 'borrador',
  programa_id SMALLINT UNSIGNED NOT NULL,
  area_id SMALLINT UNSIGNED NOT NULL,
  proponente_id BIGINT UNSIGNED NOT NULL,
  seleccionada_por BIGINT UNSIGNED NULL,
  seleccionada_hasta DATETIME NULL,
  cupos_disponibles SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  enviada_en DATETIME NULL,
  revisada_en DATETIME NULL,
  aprobada_en DATETIME NULL,
  creada_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizada_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_ideas_codigo (codigo),
  UNIQUE KEY uq_ideas_seleccionada_por (seleccionada_por),
  KEY ix_ideas_estado_tipo (estado, tipo),
  KEY ix_ideas_programa_estado (programa_id, estado),
  KEY ix_ideas_area_estado (area_id, estado),
  KEY ix_ideas_proponente (proponente_id),
  CONSTRAINT fk_ideas_programa FOREIGN KEY (programa_id)
    REFERENCES programas_academicos (id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_ideas_area FOREIGN KEY (area_id)
    REFERENCES areas_tematicas (id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_ideas_proponente FOREIGN KEY (proponente_id)
    REFERENCES usuarios (id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_ideas_estudiante_reserva FOREIGN KEY (seleccionada_por)
    REFERENCES estudiantes (usuario_id) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS revisiones_ideas (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  idea_id BIGINT UNSIGNED NOT NULL,
  revisor_id BIGINT UNSIGNED NOT NULL,
  decision ENUM('en_revision', 'requiere_ajustes', 'aprobada', 'rechazada') NOT NULL,
  observaciones TEXT NULL,
  revisada_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_revisiones_idea_fecha (idea_id, revisada_en),
  KEY ix_revisiones_revisor_fecha (revisor_id, revisada_en),
  CONSTRAINT fk_revisiones_idea FOREIGN KEY (idea_id)
    REFERENCES ideas (id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_revisiones_revisor FOREIGN KEY (revisor_id)
    REFERENCES usuarios (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS direcciones_ideas (
  idea_id BIGINT UNSIGNED NOT NULL,
  director_id BIGINT UNSIGNED NOT NULL,
  asignado_por BIGINT UNSIGNED NOT NULL,
  asignado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (idea_id),
  KEY ix_direcciones_ideas_director (director_id),
  CONSTRAINT fk_direcciones_ideas_idea FOREIGN KEY (idea_id)
    REFERENCES ideas (id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_direcciones_ideas_docente FOREIGN KEY (director_id)
    REFERENCES docentes (usuario_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_direcciones_ideas_asignador FOREIGN KEY (asignado_por)
    REFERENCES usuarios (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS evaluadores_ideas (
  idea_id BIGINT UNSIGNED NOT NULL,
  evaluador_id BIGINT UNSIGNED NOT NULL,
  asignado_por BIGINT UNSIGNED NOT NULL,
  asignado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (idea_id),
  KEY ix_evaluadores_ideas_evaluador (evaluador_id),
  CONSTRAINT fk_evaluadores_ideas_idea FOREIGN KEY (idea_id)
    REFERENCES ideas (id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_evaluadores_ideas_docente FOREIGN KEY (evaluador_id)
    REFERENCES docentes (usuario_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_evaluadores_ideas_asignador FOREIGN KEY (asignado_por)
    REFERENCES usuarios (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS anteproyectos (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  idea_id BIGINT UNSIGNED NOT NULL,
  estudiante_id BIGINT UNSIGNED NOT NULL,
  director_id BIGINT UNSIGNED NOT NULL,
  titulo VARCHAR(180) NOT NULL,
  descripcion TEXT NOT NULL,
  enlace_drive VARCHAR(500) NOT NULL,
  estado ENUM('pendiente_revision', 'pendiente_evaluador', 'aprobado', 'aplazado', 'rechazado') NOT NULL DEFAULT 'pendiente_revision',
  enviado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revisado_en DATETIME NULL,
  actualizado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_anteproyecto_idea_estudiante (idea_id, estudiante_id),
  KEY ix_anteproyectos_director_estado (director_id, estado),
  KEY ix_anteproyectos_estudiante (estudiante_id),
  CONSTRAINT fk_anteproyectos_idea FOREIGN KEY (idea_id)
    REFERENCES ideas (id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_anteproyectos_estudiante FOREIGN KEY (estudiante_id)
    REFERENCES estudiantes (usuario_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_anteproyectos_director FOREIGN KEY (director_id)
    REFERENCES docentes (usuario_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS revisiones_anteproyectos (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  anteproyecto_id BIGINT UNSIGNED NOT NULL,
  director_id BIGINT UNSIGNED NOT NULL,
  etapa ENUM('director', 'evaluador') NOT NULL DEFAULT 'director',
  decision ENUM('aprobado', 'aplazado', 'rechazado') NOT NULL,
  observaciones TEXT NULL,
  revisada_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_revision_anteproyecto_fecha (anteproyecto_id, revisada_en),
  KEY ix_revision_anteproyecto_director (director_id, revisada_en),
  CONSTRAINT fk_revision_anteproyecto FOREIGN KEY (anteproyecto_id)
    REFERENCES anteproyectos (id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_revision_anteproyecto_director FOREIGN KEY (director_id)
    REFERENCES docentes (usuario_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS proyectos_finales (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  anteproyecto_id BIGINT UNSIGNED NOT NULL,
  titulo VARCHAR(180) NOT NULL,
  descripcion TEXT NOT NULL,
  enlace_drive VARCHAR(500) NOT NULL,
  estado ENUM('pendiente_director', 'pendiente_evaluador', 'aprobado', 'aplazado', 'rechazado') NOT NULL DEFAULT 'pendiente_director',
  enviado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revisado_en DATETIME NULL,
  actualizado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_proyectos_finales_anteproyecto (anteproyecto_id),
  KEY ix_proyectos_finales_estado (estado),
  CONSTRAINT fk_proyectos_finales_anteproyecto FOREIGN KEY (anteproyecto_id)
    REFERENCES anteproyectos (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS revisiones_proyectos_finales (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  proyecto_final_id BIGINT UNSIGNED NOT NULL,
  revisor_id BIGINT UNSIGNED NOT NULL,
  etapa ENUM('director', 'evaluador') NOT NULL,
  decision ENUM('aprobado', 'aplazado', 'rechazado') NOT NULL,
  observaciones TEXT NULL,
  revisada_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_revision_proyecto_final_fecha (proyecto_final_id, revisada_en),
  KEY ix_revision_proyecto_final_revisor (revisor_id, revisada_en),
  CONSTRAINT fk_revision_proyecto_final FOREIGN KEY (proyecto_final_id)
    REFERENCES proyectos_finales (id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_revision_proyecto_final_revisor FOREIGN KEY (revisor_id)
    REFERENCES docentes (usuario_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS solicitudes_ideas (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  idea_id BIGINT UNSIGNED NOT NULL,
  estudiante_id BIGINT UNSIGNED NOT NULL,
  integrante_id BIGINT UNSIGNED NULL,
  mensaje TEXT NULL,
  comprobante_pago_url VARCHAR(500) NOT NULL,
  pago_verificado TINYINT(1) NOT NULL DEFAULT 0,
  estado ENUM('pendiente', 'aprobada', 'rechazada', 'retirada') NOT NULL DEFAULT 'pendiente',
  respuesta TEXT NULL,
  respondida_por BIGINT UNSIGNED NULL,
  creada_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  respondida_en DATETIME NULL,
  corregir_hasta DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_solicitud_idea_estudiante (idea_id, estudiante_id),
  KEY ix_solicitudes_estado_fecha (estado, creada_en),
  KEY ix_solicitudes_estudiante_estado (estudiante_id, estado),
  KEY ix_solicitudes_integrante_estado (integrante_id, estado),
  CONSTRAINT fk_solicitudes_idea FOREIGN KEY (idea_id)
    REFERENCES ideas (id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_solicitudes_estudiante FOREIGN KEY (estudiante_id)
    REFERENCES estudiantes (usuario_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_solicitudes_integrante FOREIGN KEY (integrante_id)
    REFERENCES estudiantes (usuario_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_solicitudes_responde FOREIGN KEY (respondida_por)
    REFERENCES usuarios (id) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS proyectos (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo VARCHAR(30) NOT NULL,
  titulo VARCHAR(180) NOT NULL,
  resumen TEXT NULL,
  idea_id BIGINT UNSIGNED NULL,
  solicitud_idea_id BIGINT UNSIGNED NULL,
  programa_id SMALLINT UNSIGNED NOT NULL,
  creado_por BIGINT UNSIGNED NOT NULL,
  estado ENUM('propuesto', 'aprobado', 'en_desarrollo', 'suspendido', 'finalizado', 'cancelado') NOT NULL DEFAULT 'propuesto',
  fecha_inicio DATE NULL,
  fecha_fin DATE NULL,
  creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_proyectos_codigo (codigo),
  UNIQUE KEY uq_proyectos_solicitud (solicitud_idea_id),
  KEY ix_proyectos_programa_estado (programa_id, estado),
  KEY ix_proyectos_creador (creado_por),
  KEY ix_proyectos_idea (idea_id),
  CONSTRAINT fk_proyectos_idea FOREIGN KEY (idea_id)
    REFERENCES ideas (id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_proyectos_solicitud FOREIGN KEY (solicitud_idea_id)
    REFERENCES solicitudes_ideas (id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_proyectos_programa FOREIGN KEY (programa_id)
    REFERENCES programas_academicos (id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_proyectos_creador FOREIGN KEY (creado_por)
    REFERENCES usuarios (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS integrantes_proyecto (
  proyecto_id BIGINT UNSIGNED NOT NULL,
  estudiante_id BIGINT UNSIGNED NOT NULL,
  rol_en_proyecto ENUM('lider', 'integrante') NOT NULL DEFAULT 'integrante',
  agregado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (proyecto_id, estudiante_id),
  KEY ix_integrantes_estudiante (estudiante_id),
  CONSTRAINT fk_integrantes_proyecto FOREIGN KEY (proyecto_id)
    REFERENCES proyectos (id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_integrantes_estudiante FOREIGN KEY (estudiante_id)
    REFERENCES estudiantes (usuario_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS asesores_proyecto (
  proyecto_id BIGINT UNSIGNED NOT NULL,
  docente_id BIGINT UNSIGNED NOT NULL,
  tipo_asesoria ENUM('director', 'codirector', 'asesor') NOT NULL DEFAULT 'asesor',
  asignado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (proyecto_id, docente_id),
  KEY ix_asesores_docente (docente_id),
  CONSTRAINT fk_asesores_proyecto FOREIGN KEY (proyecto_id)
    REFERENCES proyectos (id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_asesores_docente FOREIGN KEY (docente_id)
    REFERENCES docentes (usuario_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS entregables (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  proyecto_id BIGINT UNSIGNED NOT NULL,
  titulo VARCHAR(160) NOT NULL,
  descripcion TEXT NULL,
  fecha_limite DATE NULL,
  estado ENUM('pendiente', 'enviado', 'en_revision', 'aprobado', 'requiere_cambios') NOT NULL DEFAULT 'pendiente',
  archivo_url VARCHAR(500) NULL,
  enviado_por BIGINT UNSIGNED NULL,
  revisado_por BIGINT UNSIGNED NULL,
  comentarios_revision TEXT NULL,
  enviado_en DATETIME NULL,
  revisado_en DATETIME NULL,
  creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_entregables_proyecto_fecha (proyecto_id, fecha_limite),
  KEY ix_entregables_estado (estado),
  CONSTRAINT fk_entregables_proyecto FOREIGN KEY (proyecto_id)
    REFERENCES proyectos (id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_entregables_envia FOREIGN KEY (enviado_por)
    REFERENCES usuarios (id) ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT fk_entregables_revisa FOREIGN KEY (revisado_por)
    REFERENCES usuarios (id) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notificaciones (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  usuario_id BIGINT UNSIGNED NOT NULL,
  titulo VARCHAR(150) NOT NULL,
  mensaje VARCHAR(700) NOT NULL,
  tipo ENUM('general', 'idea', 'proyecto', 'entregable', 'cuenta') NOT NULL DEFAULT 'general',
  enlace VARCHAR(500) NULL,
  leida_en DATETIME NULL,
  creada_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_notificaciones_usuario_fecha (usuario_id, creada_en),
  KEY ix_notificaciones_usuario_leida (usuario_id, leida_en),
  CONSTRAINT fk_notificaciones_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS historial_proyectos (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  proyecto_id BIGINT UNSIGNED NOT NULL,
  usuario_id BIGINT UNSIGNED NULL,
  estado_anterior VARCHAR(30) NULL,
  estado_nuevo VARCHAR(30) NOT NULL,
  comentario TEXT NULL,
  registrado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_historial_proyecto_fecha (proyecto_id, registrado_en),
  CONSTRAINT fk_historial_proyecto FOREIGN KEY (proyecto_id)
    REFERENCES proyectos (id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_historial_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios (id) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE OR REPLACE VIEW ideas_aprobadas AS
SELECT
  i.id,
  i.codigo,
  i.titulo,
  i.problema,
  i.descripcion,
  i.objetivos,
  i.recursos_tecnologias,
  i.beneficiarios,
  i.tipo,
  i.cupos_disponibles,
  i.aprobada_en,
  p.id AS programa_id,
  p.nombre AS programa,
  a.id AS area_id,
  a.nombre AS area,
  u.id AS proponente_id,
  u.nombre_completo AS proponente
FROM ideas i
JOIN programas_academicos p ON p.id = i.programa_id
JOIN areas_tematicas a ON a.id = i.area_id
JOIN usuarios u ON u.id = i.proponente_id
WHERE i.estado = 'aprobada';

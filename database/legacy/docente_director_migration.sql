-- HISTÓRICO: Migración del flujo de anteproyectos dirigidos por docentes.
-- Puede ejecutarse varias veces en MariaDB 10.4 / MySQL 8.0.

USE proyectos_grado_uts;

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

-- HISTÓRICO: Flujo de proyecto final; ya está integrado en 01_create_schema.sql.
CREATE TABLE IF NOT EXISTS proyectos_finales (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  anteproyecto_id BIGINT UNSIGNED NOT NULL,
  titulo VARCHAR(180) NOT NULL,
  descripcion TEXT NOT NULL,
  enlace_drive VARCHAR(500) NOT NULL,
  estado ENUM('pendiente_director', 'pendiente_evaluador', 'aprobado', 'rechazado') NOT NULL DEFAULT 'pendiente_director',
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
  decision ENUM('aprobado', 'rechazado') NOT NULL,
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

-- HISTÓRICO: Registra un docente evaluador por idea/proyecto.
-- MariaDB 10.4 / MySQL 8.0. Reejecutable.

USE proyectos_grado_uts;

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

-- HISTÓRICO: Permite registrar opcionalmente un segundo estudiante en una solicitud de idea.
-- Ejecutar una vez sobre bases creadas antes de esta funcionalidad.

USE proyectos_grado_uts;

ALTER TABLE solicitudes_ideas
  ADD COLUMN integrante_id BIGINT UNSIGNED NULL AFTER estudiante_id,
  ADD KEY ix_solicitudes_integrante_estado (integrante_id, estado),
  ADD CONSTRAINT fk_solicitudes_integrante FOREIGN KEY (integrante_id)
    REFERENCES estudiantes (usuario_id) ON UPDATE CASCADE ON DELETE RESTRICT;

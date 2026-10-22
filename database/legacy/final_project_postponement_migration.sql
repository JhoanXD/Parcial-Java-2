-- HISTÓRICO: Aplazamientos; ya está integrado en 01_create_schema.sql.
ALTER TABLE proyectos_finales
  MODIFY estado ENUM('pendiente_director', 'pendiente_evaluador', 'aprobado', 'aplazado', 'rechazado')
    NOT NULL DEFAULT 'pendiente_director';

ALTER TABLE revisiones_proyectos_finales
  MODIFY decision ENUM('aprobado', 'aplazado', 'rechazado') NOT NULL;

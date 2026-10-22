-- HISTÓRICO: Habilita la revisión secuencial de anteproyectos por director y evaluador.
-- MariaDB 10.4+; puede ejecutarse más de una vez.

USE proyectos_grado_uts;

ALTER TABLE anteproyectos
  MODIFY estado ENUM(
    'pendiente_revision',
    'pendiente_evaluador',
    'aprobado',
    'aplazado',
    'rechazado'
  ) NOT NULL DEFAULT 'pendiente_revision';

ALTER TABLE revisiones_anteproyectos
  ADD COLUMN IF NOT EXISTS etapa ENUM('director', 'evaluador') NOT NULL DEFAULT 'director'
  AFTER director_id;

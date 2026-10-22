-- HISTÓRICO: Reserva ideas al solicitar su uso y exige el comprobante de pago enlazado.
-- La clave unica permite que cada estudiante tenga como maximo una idea reservada/asignada.
-- MariaDB 10.4 / MySQL 8.0. Reejecutable.
USE proyectos_grado_uts;

ALTER TABLE ideas
  ADD COLUMN IF NOT EXISTS seleccionada_por BIGINT UNSIGNED NULL AFTER proponente_id,
  ADD COLUMN IF NOT EXISTS seleccionada_hasta DATETIME NULL AFTER seleccionada_por;

SET @has_idea_student_fk = (
  SELECT COUNT(*)
  FROM information_schema.TABLE_CONSTRAINTS
  WHERE CONSTRAINT_SCHEMA = DATABASE()
    AND TABLE_NAME = 'ideas'
    AND CONSTRAINT_NAME = 'fk_ideas_estudiante_reserva'
    AND CONSTRAINT_TYPE = 'FOREIGN KEY'
);
SET @add_idea_student_fk = IF(
  @has_idea_student_fk = 0,
  'ALTER TABLE ideas ADD CONSTRAINT fk_ideas_estudiante_reserva FOREIGN KEY (seleccionada_por) REFERENCES estudiantes (usuario_id) ON UPDATE CASCADE ON DELETE SET NULL',
  'SELECT 1'
);
PREPARE add_idea_student_fk FROM @add_idea_student_fk;
EXECUTE add_idea_student_fk;
DEALLOCATE PREPARE add_idea_student_fk;

SET @has_idea_student_unique = (
  SELECT COUNT(*)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'ideas'
    AND INDEX_NAME = 'uq_ideas_seleccionada_por'
);
SET @add_idea_student_unique = IF(
  @has_idea_student_unique = 0,
  'ALTER TABLE ideas ADD UNIQUE KEY uq_ideas_seleccionada_por (seleccionada_por)',
  'SELECT 1'
);
PREPARE add_idea_student_unique FROM @add_idea_student_unique;
EXECUTE add_idea_student_unique;
DEALLOCATE PREPARE add_idea_student_unique;

ALTER TABLE solicitudes_ideas
  ADD COLUMN IF NOT EXISTS comprobante_pago_url VARCHAR(500) NULL AFTER mensaje,
  ADD COLUMN IF NOT EXISTS pago_verificado TINYINT(1) NOT NULL DEFAULT 0 AFTER comprobante_pago_url,
  ADD COLUMN IF NOT EXISTS corregir_hasta DATETIME NULL AFTER respondida_en;

UPDATE solicitudes_ideas
SET pago_verificado = 1
WHERE estado = 'aprobada';

-- HISTÓRICO: Semilla anterior de una idea con código duplicado en 02_insert_initial_data.sql.
-- Repetir este script no duplica la idea ni su asignacion de director.
USE proyectos_grado_uts;

START TRANSACTION;

INSERT INTO ideas (
  codigo,
  titulo,
  problema,
  descripcion,
  objetivos,
  recursos_tecnologias,
  beneficiarios,
  tipo,
  estado,
  programa_id,
  area_id,
  proponente_id,
  enviada_en
)
SELECT
  'IDEA-DOC-2026-001',
  'Sistema web para gestionar solicitudes de soporte tecnológico en la UTS',
  'Las solicitudes de soporte tecnológico recibidas por distintos canales pueden quedar dispersas, dificultando conocer su prioridad, responsable y estado de atención.',
  'Desarrollar una aplicación web para registrar solicitudes de soporte de estudiantes y personal, clasificarlas por tipo e impacto, asignarlas a un responsable y permitir consultar su avance hasta el cierre. El sistema ofrecerá un historial de atención y datos básicos para identificar problemas recurrentes.',
  'Centralizar el registro de solicitudes; permitir su clasificación y asignación; ofrecer seguimiento de estados y tiempos de atención; generar reportes de incidencias frecuentes.',
  'Aplicación web, JSP, JSTL 1.2, MariaDB, HTML y CSS.',
  'Estudiantes, docentes y personal de apoyo de la UTS.',
  'institucional',
  'pendiente_revision',
  p.id,
  a.id,
  u.id,
  NOW()
FROM usuarios u
JOIN docentes d ON d.usuario_id = u.id
JOIN usuario_roles ur ON ur.usuario_id = u.id
JOIN roles r ON r.id = ur.rol_id AND r.nombre = 'docente'
JOIN programas_academicos p ON p.codigo = 'DSI' AND p.activo = 1
JOIN areas_tematicas a ON a.codigo = 'TECNOLOGIA' AND a.activa = 1
WHERE u.correo = 'docente@uts.edu.co'
  AND u.estado = 'activo'
  AND NOT EXISTS (
    SELECT 1
    FROM ideas existente
    WHERE existente.codigo = 'IDEA-DOC-2026-001'
  )
LIMIT 1;

INSERT IGNORE INTO direcciones_ideas (idea_id, director_id, asignado_por)
SELECT i.id, u.id, u.id
FROM ideas i
JOIN usuarios u ON u.id = i.proponente_id
JOIN docentes d ON d.usuario_id = u.id
JOIN usuario_roles ur ON ur.usuario_id = u.id
JOIN roles r ON r.id = ur.rol_id AND r.nombre = 'docente'
WHERE i.codigo = 'IDEA-DOC-2026-001'
  AND i.tipo = 'institucional'
  AND i.proponente_id = u.id
  AND u.correo = 'docente@uts.edu.co'
  AND u.estado = 'activo';

COMMIT;

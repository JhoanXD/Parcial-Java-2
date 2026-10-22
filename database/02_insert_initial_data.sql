-- Datos iniciales de referencia y diez ideas institucionales de ejemplo.
-- Los docentes con ID 10 y 25 deben existir antes de ejecutar la sección de ideas.
-- Ejecutar después de 01_create_schema.sql y cargar las cuentas docentes base.
USE proyectos_grado_uts;

INSERT IGNORE INTO roles (nombre, descripcion) VALUES
  ('administrador', 'Administra usuarios y parámetros de la plataforma'),
  ('coordinador', 'Revisa y aprueba ideas y proyectos de grado'),
  ('docente', 'Asesora proyectos y revisa entregables'),
  ('estudiante', 'Consulta ideas y propone o desarrolla proyectos');

INSERT IGNORE INTO areas_tematicas (codigo, nombre, descripcion) VALUES
  ('TECNOLOGIA', 'Tecnología e innovación', 'Soluciones tecnológicas e innovación'),
  ('AMBIENTAL', 'Medio ambiente', 'Sostenibilidad y gestión ambiental'),
  ('BIENESTAR', 'Bienestar y salud', 'Bienestar y calidad de vida'),
  ('EDUCACION', 'Educación', 'Procesos y herramientas educativas'),
  ('GESTION', 'Gestión empresarial', 'Gestión, emprendimiento y productividad'),
  ('OTRA', 'Otra área', 'Área temática no incluida en las anteriores');

INSERT IGNORE INTO programas_academicos (codigo, nombre) VALUES
  ('DSI', 'Tecnología en Desarrollo de Sistemas Informáticos'),
  ('MRA', 'Tecnología en Manejo de Recursos Ambientales'),
  ('OMEM', 'Tecnología en Operación y Mantenimiento Electromecánico');

START TRANSACTION;

CREATE TEMPORARY TABLE seed_teacher_ideas (
  codigo VARCHAR(24) NOT NULL PRIMARY KEY,
  titulo VARCHAR(180) NOT NULL,
  problema TEXT NOT NULL,
  descripcion TEXT NOT NULL,
  objetivos TEXT NOT NULL,
  recursos_tecnologias TEXT NOT NULL,
  beneficiarios VARCHAR(500) NOT NULL,
  programa_id SMALLINT UNSIGNED NOT NULL,
  area_id SMALLINT UNSIGNED NOT NULL,
  proponente_id BIGINT UNSIGNED NOT NULL
);

INSERT INTO seed_teacher_ideas (
  codigo,titulo,problema,descripcion,objetivos,recursos_tecnologias,beneficiarios,programa_id,area_id,proponente_id
) VALUES
(
  'IDEA-DOC-2026-001',
  'Plataforma de inventario y mantenimiento de equipos de laboratorio',
  'La información sobre equipos, responsables, garantías y mantenimientos de laboratorio puede estar distribuida en registros separados, dificultando conocer la disponibilidad y anticipar fallas.',
  'Desarrollar una aplicación web para registrar equipos por laboratorio, consultar su estado, programar mantenimientos preventivos y conservar el historial de intervenciones. Incluirá alertas para mantenimientos próximos y reportes de disponibilidad.',
  'Centralizar el inventario; consultar disponibilidad y estado; programar mantenimientos preventivos; conservar el historial técnico y generar reportes.',
  'JSP, JSTL 1.2, MariaDB, HTML, CSS y generación de reportes.',
  'Docentes, técnicos y estudiantes que utilizan los laboratorios.',
  1,1,10
),
(
  'IDEA-DOC-2026-002',
  'Sistema de reserva de salas y recursos académicos',
  'La reserva de salas, proyectores y otros recursos mediante comunicaciones dispersas puede causar cruces de horario y dificultar conocer la disponibilidad.',
  'Implementar un sistema web de consulta y reserva de espacios y recursos académicos. Permitirá buscar por capacidad, ubicación y horario, registrar solicitudes, aplicar reglas de aprobación y consultar el calendario de reservas.',
  'Publicar la disponibilidad; prevenir reservas duplicadas; gestionar solicitudes y aprobaciones; ofrecer calendarios y reportes de uso.',
  'Aplicación web, base de datos relacional, calendario interactivo y autenticación por roles.',
  'Estudiantes, docentes y personal encargado de los espacios académicos.',
  1,4,10
),
(
  'IDEA-DOC-2026-003',
  'Tablero de seguimiento de prácticas y proyectos formativos',
  'El seguimiento de prácticas y proyectos formativos puede depender de documentos y mensajes separados, haciendo difícil identificar entregas pendientes y necesidades de acompañamiento.',
  'Crear una plataforma para registrar planes de trabajo, hitos, entregas y observaciones de tutores. Cada participante podrá consultar el avance y recibir alertas sobre fechas próximas o actividades atrasadas.',
  'Organizar hitos y entregas; documentar observaciones; visualizar avances por estudiante; alertar sobre fechas y pendientes.',
  'Aplicación web, MariaDB, notificaciones por correo y paneles de seguimiento.',
  'Estudiantes, docentes tutores y coordinadores de prácticas.',
  1,4,10
),
(
  'IDEA-DOC-2026-004',
  'Registro georreferenciado de puntos críticos de residuos',
  'La ubicación y recurrencia de puntos con acumulación inadecuada de residuos suele registrarse de forma no estandarizada, limitando la priorización de acciones ambientales.',
  'Desarrollar una herramienta para reportar puntos críticos con ubicación, tipo de residuo, fecha y evidencia fotográfica. Un mapa permitirá consultar reportes, identificar recurrencias y hacer seguimiento a acciones de mitigación.',
  'Estandarizar reportes ambientales; representar puntos en un mapa; identificar zonas recurrentes; documentar acciones y resultados.',
  'Aplicación web móvil, mapas OpenStreetMap, geolocalización y base de datos espacial o coordenadas geográficas.',
  'Comunidades, gestores ambientales y equipos de respuesta local.',
  2,2,10
),
(
  'IDEA-DOC-2026-005',
  'Monitoreo del consumo energético en talleres electromecánicos',
  'La lectura periódica y manual del consumo eléctrico dificulta detectar equipos o periodos de uso ineficiente en talleres de formación.',
  'Construir un prototipo de monitoreo que registre mediciones de consumo por equipo o circuito y presente tendencias, horarios de mayor demanda y alertas por valores atípicos para apoyar decisiones de ahorro.',
  'Registrar consumo energético; visualizar tendencias por periodo; identificar patrones atípicos; proponer medidas de eficiencia.',
  'Sensores de corriente, microcontrolador, comunicación MQTT, API de registro y tablero web.',
  'Estudiantes y docentes de talleres; responsables de infraestructura y mantenimiento.',
  3,1,10
),
(
  'IDEA-DOC-2026-006',
  'Aplicación de orientación y acceso a servicios de bienestar estudiantil',
  'Los estudiantes pueden tener dificultades para identificar los servicios de bienestar disponibles, sus horarios, requisitos y canales de atención.',
  'Diseñar un portal accesible que reúna información de servicios de bienestar, preguntas frecuentes, horarios y rutas de solicitud. Incluirá filtros por necesidad y enlaces a los canales oficiales de atención.',
  'Centralizar información verificada; facilitar la búsqueda de servicios; mejorar la accesibilidad; orientar a los estudiantes hacia canales oficiales.',
  'Aplicación web responsiva, criterios WCAG, gestor de contenidos y analítica agregada sin datos sensibles.',
  'Estudiantes y equipos de bienestar institucional.',
  1,3,25
),
(
  'IDEA-DOC-2026-007',
  'Gestor de prácticas de desarrollo de software con control de calidad',
  'En proyectos académicos de software, los requisitos, incidencias, versiones y resultados de pruebas pueden quedar separados y dificultar la trazabilidad del trabajo.',
  'Implementar un gestor académico que relacione requisitos con tareas, incidencias, versiones y evidencias de pruebas. Permitirá consultar cambios, responsables y resultados de validación por iteración.',
  'Relacionar requisitos con tareas y pruebas; registrar incidencias y cambios; consultar responsables; generar trazabilidad por iteración.',
  'Aplicación web, Git, integración con repositorios, MariaDB y ejecución automatizada de pruebas.',
  'Estudiantes y docentes de proyectos de desarrollo de software.',
  1,1,25
),
(
  'IDEA-DOC-2026-008',
  'Seguimiento comunitario de calidad de agua en fuentes locales',
  'Las observaciones y mediciones comunitarias de fuentes de agua pueden quedar aisladas, sin una serie histórica sencilla para reconocer cambios y orientar verificaciones.',
  'Crear una plataforma para registrar mediciones básicas de campo, fecha, ubicación, método y observaciones. El sistema visualizará series temporales y señalará valores que requieran confirmación por personal competente, sin sustituir análisis de laboratorio.',
  'Estandarizar registros de campo; conservar ubicación y método; visualizar tendencias; facilitar la identificación de mediciones que requieren verificación.',
  'Formularios móviles, sensores básicos de pH y turbidez, georreferenciación y tablero de series temporales.',
  'Comunidades, estudiantes y equipos de gestión ambiental.',
  2,2,25
),
(
  'IDEA-DOC-2026-009',
  'Banco digital de iniciativas de economía circular local',
  'Los emprendimientos y organizaciones locales pueden desconocer oportunidades de reutilización de materiales y no contar con un espacio para conectar oferta y demanda de recursos aprovechables.',
  'Desarrollar un catálogo digital de materiales reutilizables y necesidades de aprovechamiento, con categorías, ubicación aproximada, cantidades y condiciones de entrega. La plataforma facilitará contactos entre participantes y registrará resultados de intercambio.',
  'Publicar materiales y necesidades; facilitar coincidencias entre oferta y demanda; promover reutilización; medir intercambios reportados.',
  'Aplicación web, catálogo con búsqueda, base de datos relacional y panel de indicadores agregados.',
  'Emprendimientos, asociaciones, unidades productivas y gestores locales.',
  2,5,25
),
(
  'IDEA-DOC-2026-010',
  'Sistema digital de órdenes de trabajo y repuestos para equipos electromecánicos',
  'Las órdenes de mantenimiento de equipos electromecánicos pueden carecer de seguimiento uniforme y de una relación clara con las piezas utilizadas y las fallas recurrentes.',
  'Construir un sistema para registrar órdenes correctivas y preventivas, asignar responsables, documentar diagnóstico y actividades, y asociar repuestos utilizados. Los reportes ayudarán a analizar tiempos de atención y necesidades de abastecimiento.',
  'Centralizar órdenes de trabajo; documentar diagnóstico e intervención; relacionar repuestos con equipos; analizar tiempos y recurrencias.',
  'Aplicación web, MariaDB, códigos QR para identificar equipos y reportes operativos.',
  'Personal de mantenimiento, docentes y estudiantes de formación electromecánica.',
  3,1,25
);

INSERT INTO ideas (
  codigo,titulo,problema,descripcion,objetivos,recursos_tecnologias,beneficiarios,
  tipo,estado,programa_id,area_id,proponente_id,enviada_en
)
SELECT seed.codigo,seed.titulo,seed.problema,seed.descripcion,seed.objetivos,seed.recursos_tecnologias,seed.beneficiarios,
  'institucional','pendiente_revision',seed.programa_id,seed.area_id,seed.proponente_id,NOW()
FROM seed_teacher_ideas seed
JOIN usuarios u ON u.id=seed.proponente_id AND u.estado='activo'
JOIN docentes d ON d.usuario_id=u.id
JOIN usuario_roles ur ON ur.usuario_id=u.id
JOIN roles r ON r.id=ur.rol_id AND r.nombre='docente'
JOIN programas_academicos p ON p.id=seed.programa_id AND p.activo=1
JOIN areas_tematicas a ON a.id=seed.area_id AND a.activa=1
WHERE NOT EXISTS (SELECT 1 FROM ideas existing WHERE existing.codigo=seed.codigo);

INSERT INTO direcciones_ideas (idea_id,director_id,asignado_por)
SELECT i.id,i.proponente_id,i.proponente_id
FROM ideas i
JOIN seed_teacher_ideas seed ON seed.codigo=i.codigo
WHERE i.tipo='institucional' AND i.proponente_id=seed.proponente_id
  AND i.estado='pendiente_revision'
ON DUPLICATE KEY UPDATE director_id=VALUES(director_id);

DROP TEMPORARY TABLE seed_teacher_ideas;

COMMIT;

<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<c:choose>
  <c:when test="${empty sessionScope.userId}"><c:redirect url="/login.jsp" /></c:when>
  <c:otherwise>
    <sql:query var="activeStudent" dataSource="jdbc/ProjectsDB">
      SELECT u.id,u.nombre_completo,r.nombre AS rol,e.programa_id
      FROM usuarios u JOIN usuario_roles ur ON ur.usuario_id=u.id JOIN roles r ON r.id=ur.rol_id
      JOIN estudiantes e ON e.usuario_id=u.id
      WHERE u.id=? AND u.estado='activo'
      ORDER BY CASE r.nombre WHEN 'administrador' THEN 1 WHEN 'coordinador' THEN 2 WHEN 'docente' THEN 3 ELSE 4 END
      LIMIT 1
      <sql:param value="${sessionScope.userId}" />
    </sql:query>
    <c:choose>
      <c:when test="${empty activeStudent.rows}"><c:remove var="userId" scope="session" /><c:remove var="userName" scope="session" /><c:remove var="userRole" scope="session" /><c:redirect url="/login.jsp" /></c:when>
      <c:when test="${activeStudent.rows[0].rol eq 'administrador'}"><c:redirect url="/admin-usuarios.jsp" /></c:when>
      <c:when test="${activeStudent.rows[0].rol eq 'coordinador'}"><c:redirect url="/coordinador-ideas.jsp" /></c:when>
      <c:when test="${activeStudent.rows[0].rol eq 'docente'}"><c:redirect url="/docente.jsp" /></c:when>
      <c:when test="${activeStudent.rows[0].rol ne 'estudiante'}"><c:redirect url="/login.jsp" /></c:when>
      <c:otherwise><c:set var="currentUserName" value="${activeStudent.rows[0].nombre_completo}" /></c:otherwise>
    </c:choose>
  </c:otherwise>
</c:choose>
<c:if test="${empty sessionScope.csrfToken}"><sql:query var="newCsrf" dataSource="jdbc/ProjectsDB">SELECT LOWER(SHA2(CONCAT(UUID(), RAND(), UUID(), NOW(6)), 256)) AS token</sql:query><c:set var="csrfToken" value="${newCsrf.rows[0].token}" scope="session" /></c:if>
<c:if test="${pageContext.request.method eq 'POST'}">
  <c:choose>
    <c:when test="${empty sessionScope.csrfToken or empty param.csrfToken or sessionScope.csrfToken ne param.csrfToken}"><c:set var="flashError" value="El formulario expiró. Recarga la página e inténtalo de nuevo." scope="session" /></c:when>
    <c:when test="${empty fn:trim(param.description) or fn:length(param.description) gt 3000 or fn:length(fn:trim(param.driveUrl)) gt 500 or (not fn:startsWith(fn:toLowerCase(fn:trim(param.driveUrl)),'https://drive.google.com/') and not fn:startsWith(fn:toLowerCase(fn:trim(param.driveUrl)),'https://docs.google.com/'))}">
      <c:set var="flashError" value="Completa la descripción y pega un enlace compartible de Google Drive o Google Docs." scope="session" />
    </c:when>
    <c:when test="${param.action eq 'submitFinalProject'}">
      <c:catch var="finalProjectSubmitFailure">
        <sql:update var="createdFinalProject" dataSource="jdbc/ProjectsDB">
          INSERT INTO proyectos_finales (anteproyecto_id,titulo,descripcion,enlace_drive)
          SELECT ap.id,ap.titulo,?,?
          FROM anteproyectos ap
          JOIN solicitudes_ideas s ON s.idea_id=ap.idea_id AND s.estudiante_id=ap.estudiante_id AND s.estado='aprobada'
          JOIN ideas i ON i.id=ap.idea_id AND i.estado='aprobada' AND i.seleccionada_por=ap.estudiante_id
          JOIN usuarios u ON u.id=ap.estudiante_id AND u.estado='activo'
          WHERE ap.id=? AND ap.estudiante_id=? AND ap.estado='aprobado'
          <sql:param value="${fn:trim(param.description)}" />
          <sql:param value="${fn:trim(param.driveUrl)}" />
          <sql:param value="${param.anteproyectoId}" />
          <sql:param value="${sessionScope.userId}" />
        </sql:update>
      </c:catch>
      <c:choose>
        <c:when test="${not empty finalProjectSubmitFailure}"><c:set var="flashError" value="No se pudo enviar el proyecto. Comprueba que no exista ya una entrega final para este anteproyecto." scope="session" /></c:when>
        <c:when test="${createdFinalProject ne 1}"><c:set var="flashError" value="Solo puedes enviar el proyecto cuando el anteproyecto esté aprobado y a tu nombre." scope="session" /></c:when>
        <c:otherwise><c:set var="flashNotice" value="El proyecto final se envió al director para su revisión." scope="session" /></c:otherwise>
      </c:choose>
    </c:when>
    <c:when test="${param.action eq 'resubmitFinalProject'}">
      <c:set var="updatedFinalProject" value="0" />
      <c:catch var="finalProjectResubmitFailure">
        <sql:transaction dataSource="jdbc/ProjectsDB">
          <sql:query var="finalProjectToResubmit">
            SELECT review.etapa
            FROM proyectos_finales pf
            JOIN anteproyectos ap ON ap.id=pf.anteproyecto_id
            JOIN revisiones_proyectos_finales review ON review.id=(
              SELECT MAX(latest.id) FROM revisiones_proyectos_finales latest WHERE latest.proyecto_final_id=pf.id
            )
            WHERE pf.id=? AND pf.estado='aplazado' AND review.decision='aplazado'
              AND ap.estudiante_id=? AND ap.estado='aprobado'
            FOR UPDATE
            <sql:param value="${param.finalProjectId}" />
            <sql:param value="${sessionScope.userId}" />
          </sql:query>
          <c:if test="${not empty finalProjectToResubmit.rows}">
            <sql:update var="updatedFinalProject">
              UPDATE proyectos_finales pf
              JOIN anteproyectos ap ON ap.id=pf.anteproyecto_id
              SET pf.descripcion=?,pf.enlace_drive=?,
                pf.estado='pendiente_director',
                pf.enviado_en=NOW(),pf.revisado_en=NULL
              WHERE pf.id=? AND pf.estado='aplazado' AND ap.estudiante_id=? AND ap.estado='aprobado'
              <sql:param value="${fn:trim(param.description)}" />
              <sql:param value="${fn:trim(param.driveUrl)}" />
              <sql:param value="${param.finalProjectId}" />
              <sql:param value="${sessionScope.userId}" />
            </sql:update>
          </c:if>
        </sql:transaction>
      </c:catch>
      <c:choose>
        <c:when test="${not empty finalProjectResubmitFailure}"><c:set var="flashError" value="No se pudo reenviar el proyecto final. Verifica el enlace e inténtalo nuevamente." scope="session" /></c:when>
        <c:when test="${updatedFinalProject ne 1}"><c:set var="flashError" value="Solo puedes corregir proyectos finales aplazados que estén a tu nombre." scope="session" /></c:when>
        <c:otherwise><c:set var="flashNotice" value="El proyecto final corregido fue enviado nuevamente al director para revisión." scope="session" /></c:otherwise>
      </c:choose>
    </c:when>
    <c:when test="${param.action eq 'submit'}">
      <c:catch var="submitFailure">
        <sql:update var="createdSubmission" dataSource="jdbc/ProjectsDB">
          INSERT INTO anteproyectos (idea_id,estudiante_id,director_id,titulo,descripcion,enlace_drive)
          SELECT i.id,?,d.director_id,i.titulo,?,?
          FROM ideas i JOIN direcciones_ideas d ON d.idea_id=i.id
          JOIN estudiantes e ON e.usuario_id=?
          JOIN solicitudes_ideas s ON s.idea_id=i.id AND s.estudiante_id=e.usuario_id AND s.estado='aprobada'
          WHERE i.id=? AND i.estado='aprobada' AND i.programa_id=e.programa_id AND i.seleccionada_por=e.usuario_id
            AND EXISTS (SELECT 1 FROM usuarios u WHERE u.id=e.usuario_id AND u.estado='activo')
          <sql:param value="${sessionScope.userId}" />
          <sql:param value="${fn:trim(param.description)}" />
          <sql:param value="${fn:trim(param.driveUrl)}" />
          <sql:param value="${sessionScope.userId}" />
          <sql:param value="${param.ideaId}" />
        </sql:update>
      </c:catch>
      <c:choose>
        <c:when test="${not empty submitFailure}"><c:set var="flashError" value="No se pudo enviar el anteproyecto. Comprueba que no exista ya una entrega para esa idea." scope="session" /></c:when>
        <c:when test="${createdSubmission ne 1}"><c:set var="flashError" value="La idea no está aprobada, no tiene director asignado o no pertenece a tu programa." scope="session" /></c:when>
        <c:otherwise><c:set var="flashNotice" value="El anteproyecto se envió a tu director para revisión." scope="session" /></c:otherwise>
      </c:choose>
    </c:when>
    <c:when test="${param.action eq 'resubmit' and not empty param.anteproyectoId}">
      <c:catch var="resubmitFailure">
        <sql:update var="updatedSubmission" dataSource="jdbc/ProjectsDB">
          UPDATE anteproyectos
          SET descripcion=?,enlace_drive=?,estado='pendiente_revision',enviado_en=NOW(),revisado_en=NULL
          WHERE id=? AND estudiante_id=? AND estado='aplazado'
          <sql:param value="${fn:trim(param.description)}" />
          <sql:param value="${fn:trim(param.driveUrl)}" />
          <sql:param value="${param.anteproyectoId}" />
          <sql:param value="${sessionScope.userId}" />
        </sql:update>
      </c:catch>
      <c:choose>
        <c:when test="${not empty resubmitFailure}"><c:set var="flashError" value="No se pudo reenviar el anteproyecto. Verifica el enlace e inténtalo de nuevo." scope="session" /></c:when>
        <c:when test="${updatedSubmission ne 1}"><c:set var="flashError" value="Solo puedes reenviar anteproyectos aplazados que estén a tu nombre." scope="session" /></c:when>
        <c:otherwise><c:set var="flashNotice" value="El anteproyecto corregido se envió nuevamente a revisión del director." scope="session" /></c:otherwise>
      </c:choose>
    </c:when>
    <c:otherwise><c:set var="flashError" value="La operación solicitada no es válida." scope="session" /></c:otherwise>
  </c:choose>
  <c:redirect url="/anteproyecto.jsp" />
</c:if>
<c:if test="${not empty sessionScope.flashNotice}"><c:set var="pageNotice" value="${sessionScope.flashNotice}" /><c:remove var="flashNotice" scope="session" /></c:if>
<c:if test="${not empty sessionScope.flashError}"><c:set var="pageError" value="${sessionScope.flashError}" /><c:remove var="flashError" scope="session" /></c:if>
<sql:query var="eligibleIdeas" dataSource="jdbc/ProjectsDB">
  SELECT i.id,i.codigo,i.titulo,u.nombre_completo AS director
  FROM ideas i
  JOIN direcciones_ideas d ON d.idea_id=i.id
  JOIN solicitudes_ideas s ON s.idea_id=i.id AND s.estudiante_id=? AND s.estado='aprobada'
  JOIN usuarios u ON u.id=d.director_id
  WHERE i.estado='aprobada' AND i.programa_id=? AND i.seleccionada_por=?
    AND NOT EXISTS (SELECT 1 FROM anteproyectos ap WHERE ap.idea_id=i.id AND ap.estudiante_id=?)
  ORDER BY i.titulo
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${activeStudent.rows[0].programa_id}" />
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<sql:query var="studentAnteproyectos" dataSource="jdbc/ProjectsDB">
  SELECT ap.id,ap.titulo,ap.descripcion,ap.enlace_drive,ap.estado,ap.enviado_en,
    i.codigo AS idea_codigo,i.titulo AS idea_titulo,i.problema AS idea_problema,
    i.descripcion AS idea_descripcion,i.objetivos AS idea_objetivos,
    i.recursos_tecnologias AS idea_recursos,i.beneficiarios AS idea_beneficiarios,
    idea_program.nombre AS idea_programa,idea_area.nombre AS idea_area,
    d.nombre_completo AS director,
    evaluator.nombre_completo AS evaluador,
    CASE WHEN team_request.integrante_id=? THEN leader.nombre_completo ELSE partner.nombre_completo END AS integrante,
    ap.estudiante_id AS lider_id,phase_request.estado AS solicitud_estado,r.etapa,r.decision,r.observaciones,r.revisada_en,
    final_project.id AS proyecto_final_id,final_project.titulo AS proyecto_final_titulo,
    final_project.descripcion AS proyecto_final_descripcion,final_project.enlace_drive AS proyecto_final_enlace,
    final_project.estado AS proyecto_final_estado,final_project.enviado_en AS proyecto_final_enviado_en,
    final_review.etapa AS proyecto_final_etapa,final_review.decision AS proyecto_final_decision,
    final_review.observaciones AS proyecto_final_observaciones,final_review.revisada_en AS proyecto_final_revisada_en,
    CASE
      WHEN phase_request.estado<>'aprobada' OR phase_request.pago_verificado=0 THEN 1
      WHEN final_project.estado='pendiente_director' THEN 5
      WHEN final_project.estado='rechazado' AND final_review.etapa='director' THEN 5
      WHEN final_project.estado='aplazado' THEN 4
      WHEN final_project.estado IN ('pendiente_evaluador','aprobado') THEN 6
      WHEN final_project.estado='rechazado' AND final_review.etapa='evaluador' THEN 6
      WHEN ap.estado='aplazado' AND r.etapa='evaluador' THEN 1
      WHEN ap.estado='pendiente_revision' THEN 2
      WHEN ap.estado='pendiente_evaluador' THEN 3
      WHEN ap.estado='aprobado' THEN 4
      WHEN ap.estado='aplazado' THEN 2
      WHEN ap.estado='rechazado' THEN CASE WHEN r.etapa='evaluador' THEN 3 ELSE 2 END
      ELSE 1
    END AS fase_actual
  FROM anteproyectos ap
  JOIN ideas i ON i.id=ap.idea_id
  JOIN programas_academicos idea_program ON idea_program.id=i.programa_id
  JOIN areas_tematicas idea_area ON idea_area.id=i.area_id
  JOIN usuarios d ON d.id=ap.director_id
  LEFT JOIN solicitudes_ideas phase_request ON phase_request.idea_id=ap.idea_id AND phase_request.estudiante_id=ap.estudiante_id
  LEFT JOIN solicitudes_ideas team_request
    ON team_request.idea_id=ap.idea_id AND team_request.estudiante_id=ap.estudiante_id
    AND team_request.estado='aprobada'
  LEFT JOIN evaluadores_ideas ei ON ei.idea_id=ap.idea_id
  LEFT JOIN usuarios evaluator ON evaluator.id=ei.evaluador_id
  LEFT JOIN usuarios leader ON leader.id=ap.estudiante_id
  LEFT JOIN usuarios partner ON partner.id=team_request.integrante_id
  LEFT JOIN proyectos_finales final_project ON final_project.anteproyecto_id=ap.id
  LEFT JOIN revisiones_proyectos_finales final_review ON final_review.id=(
    SELECT MAX(review.id) FROM revisiones_proyectos_finales review WHERE review.proyecto_final_id=final_project.id
  )
  LEFT JOIN revisiones_anteproyectos r ON r.id=(SELECT MAX(lr.id) FROM revisiones_anteproyectos lr WHERE lr.anteproyecto_id=ap.id)
  WHERE (ap.estudiante_id=? OR team_request.integrante_id=?)
    AND (final_project.id IS NULL OR final_project.estado<>'aprobado')
  ORDER BY ap.actualizado_en DESC,ap.id DESC
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<sql:query var="completedStudentProjects" dataSource="jdbc/ProjectsDB">
  SELECT COUNT(*) AS total
  FROM proyectos_finales pf
  JOIN anteproyectos ap ON ap.id=pf.anteproyecto_id
  LEFT JOIN solicitudes_ideas team_request ON team_request.idea_id=ap.idea_id
    AND team_request.estudiante_id=ap.estudiante_id AND team_request.estado='aprobada'
  WHERE pf.estado='aprobado' AND (ap.estudiante_id=? OR team_request.integrante_id=?)
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<c:url var="stylesUrl" value="/assets/css/styles.css?v=20261016k" />
<c:url var="homeUrl" value="/index.jsp" />
<c:url var="ideasUrl" value="/banco-ideas.jsp" />
<c:url var="myIdeasUrl" value="/mis-ideas.jsp" />
<c:url var="anteproyectoUrl" value="/anteproyecto.jsp" />
<c:url var="proposalUrl" value="/crear-idea.jsp" />
<c:url var="requestsUrl" value="/solicitudes-ideas.jsp" />
<c:url var="logoutUrl" value="/logout.jsp" />
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="theme-color" content="#f5f7f6">
  <title>Mis anteproyectos | Proyectos de grado UTS</title>
  <link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet"><link rel="stylesheet" href="${stylesUrl}">
</head>
<body>
  <div class="app-shell">
    <input class="sidebar-toggle" id="sidebarToggle" type="checkbox" aria-label="Mostrar menú">
    <aside class="sidebar">
      <a class="brand sidebar-brand" href="${homeUrl}" aria-label="UTS Proyectos de grado, inicio"><span class="brand-mark" aria-hidden="true"><span>U</span><span>T</span><span>S</span></span><span class="brand-copy"><strong>UTS</strong><span>Proyectos de grado</span></span></a>
      <div class="sidebar-label">MENÚ PRINCIPAL</div>
      <nav class="side-nav" aria-label="Menú principal">
        <a class="nav-link" href="${homeUrl}"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="m3.5 10 8.5-7 8.5 7v9a1.5 1.5 0 0 1-1.5 1.5h-14A1.5 1.5 0 0 1 3.5 19v-9Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M9 20.5v-7h6v7" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/></svg>Inicio</a>
        <a class="nav-link" href="${ideasUrl}"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M9 18h6m-5 3h4m-2-19a7 7 0 0 0-4.2 12.6c.8.6 1.2 1.3 1.2 2.4h6c0-1.1.4-1.8 1.2-2.4A7 7 0 0 0 12 2Z" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>Banco de ideas</a>
        <a class="nav-link" href="${proposalUrl}"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 5v14m-7-7h14" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.7"/></svg>Proponer una idea</a>
        <a class="nav-link" href="${myIdeasUrl}"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5" stroke="currentColor" stroke-width="1.7"/><path d="M8 5V3.5h8V5m-12.5 5h17m-13 4h4m-4 3h8" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round" stroke-linecap="round"/></svg>Mis ideas</a>
        <a class="nav-link active" href="${anteproyectoUrl}" aria-current="page"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M5 3.5h9l5 5v12H5v-17Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M14 3.5v5h5M8 13h8m-8 3.5h8" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>Mis anteproyectos</a>
        <a class="nav-link" href="${requestsUrl}"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5" stroke="currentColor" stroke-width="1.7"/><path d="M8 5V3.5h8V5m-12.5 5h17m-13 4h4m-4 3h8" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round" stroke-linecap="round"/></svg>Mis solicitudes</a>
        <a class="nav-link" href="https://www.uts.edu.co/calendario-academico/" target="_blank" rel="noopener noreferrer"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5" stroke="currentColor" stroke-width="1.7"/><path d="M7.5 3.5v3m9-3v3m-13 3h17m-13 4h3m3 0h3m-9 3.5h3" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>Calendario académico <span aria-hidden="true">↗</span></a>
      </nav>
      <div class="sidebar-bottom"><div class="admin-security-card"><span aria-hidden="true">✓</span><strong>Entrega digital</strong><p>Comparte un enlace de Google Drive con permiso de lectura para tu director.</p></div><div class="sidebar-version">PLATAFORMA DE PROYECTOS <span>v1.0</span></div></div>
    </aside>
    <label class="sidebar-overlay" for="sidebarToggle" aria-label="Cerrar menú"></label>
    <section class="main-area">
      <header class="topbar"><label class="mobile-menu" for="sidebarToggle" aria-label="Abrir menú"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg></label><div class="breadcrumb"><a href="${homeUrl}">Estudiante</a><span class="crumb-slash">/</span><strong>Mis anteproyectos</strong></div><div class="topbar-actions"><span class="demo-badge"><i></i> PORTAL ESTUDIANTIL</span><span class="topbar-divider"></span><a class="profile-button" href="${logoutUrl}"><span class="avatar"><c:out value="${fn:toUpperCase(fn:substring(currentUserName,0,1))}" /></span><span class="profile-info"><strong><c:out value="${currentUserName}" /></strong><small>Estudiante · Cerrar sesión</small></span></a></div></header>
      <main class="proposal-page anteproject-page">
        <div class="proposal-heading"><div><a class="back-link" href="${homeUrl}"><span aria-hidden="true">←</span> Volver al inicio</a><p class="section-overline"><span></span> ENTREGA Y SEGUIMIENTO</p><h1>Mis anteproyectos</h1><p class="proposal-intro">Envía a tu director un enlace compartible de Google Drive y consulta aquí sus decisiones y observaciones.</p></div></div>
        <c:if test="${not empty pageError}"><div class="admin-alert admin-alert-error" role="alert"><strong>No se completó la operación.</strong><span><c:out value="${pageError}" /></span></div></c:if>
        <c:if test="${not empty pageNotice}"><div class="admin-alert admin-alert-success" role="status"><strong>Operación completada</strong><span><c:out value="${pageNotice}" /></span></div></c:if>
        <c:if test="${completedStudentProjects.rows[0].total gt 0}"><div class="admin-alert admin-alert-success" role="status"><strong>¡Felicidades!</strong><span>Tu proyecto fue aprobado. ¡Ya te puedes graduar!</span></div></c:if>
        <c:if test="${empty eligibleIdeas.rows}">
          <div class="admin-empty-state anteproject-availability-notice" role="status">
            <c:choose>
              <c:when test="${not empty studentAnteproyectos.rows}">
                <strong>Ya enviaste el anteproyecto de tus ideas asignadas.</strong>
                <span>Para evitar duplicados, no se puede enviar otra entrega para la misma idea. Consulta abajo su estado y las decisiones del director y del evaluador.</span>
              </c:when>
              <c:otherwise>
                <strong>Aún no tienes una idea disponible para enviar al director.</strong>
                <span>El formulario aparecerá cuando una idea de tu programa haya sido aprobada y asignada a tu solicitud.</span>
              </c:otherwise>
            </c:choose>
          </div>
        </c:if>
        <c:if test="${not empty eligibleIdeas.rows}">
          <section class="admin-create-card anteproject-submit-card" aria-labelledby="submitAnteprojectTitle">
            <div class="admin-card-heading"><span class="admin-card-icon" aria-hidden="true">+</span><div><h2 id="submitAnteprojectTitle">Enviar un anteproyecto</h2><p>Selecciona una idea aprobada de tu programa. El título se toma de la idea y el director es el asignado por coordinación.</p></div></div>
            <form class="teacher-idea-form" action="${anteproyectoUrl}" method="post">
              <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="action" value="submit">
              <label class="admin-field teacher-field-wide"><span>Idea aprobada <i>*</i></span><select name="ideaId" required><option value="">Selecciona una idea aprobada</option><c:forEach var="idea" items="${eligibleIdeas.rows}"><option value="<c:out value='${idea.id}' />"><c:out value="${idea.titulo}" /> — Director: <c:out value="${idea.director}" /></option></c:forEach></select></label>
              <label class="admin-field teacher-field-wide"><span>Descripción breve <i>*</i></span><textarea name="description" maxlength="3000" rows="4" required></textarea></label>
              <label class="admin-field teacher-field-wide"><span>Enlace de Google Drive o Google Docs <i>*</i></span><input name="driveUrl" type="url" maxlength="500" placeholder="https://drive.google.com/..." required><small>Configura el archivo como “Cualquier persona con el enlace puede ver”.</small></label>
              <div class="teacher-idea-submit"><button class="button button-primary" type="submit">Enviar al director <span aria-hidden="true">→</span></button></div>
            </form>
          </section>
        </c:if>
        <section class="teacher-ideas-history" aria-labelledby="studentAnteprojectsTitle"><div class="coordinator-history-heading"><div><p class="section-overline"><span></span> MIS ENTREGAS</p><h2 id="studentAnteprojectsTitle">Seguimiento de proyectos</h2><p>Consulta el avance del anteproyecto y la revisión del proyecto final.</p></div><span class="admin-list-count"><c:out value="${fn:length(studentAnteproyectos.rows)}" /> entregas</span></div>
          <c:choose>
            <c:when test="${empty studentAnteproyectos.rows}">
              <div class="admin-empty-state"><strong>Aún no has enviado anteproyectos.</strong><span>Las ideas aprobadas y con director asignado estarán disponibles para realizar una entrega.</span></div>
            </c:when>
            <c:otherwise>
              <div class="coordinator-list">
                <c:forEach var="submission" items="${studentAnteproyectos.rows}">
                  <article class="coordinator-idea-card">
                    <header class="coordinator-idea-heading">
                      <div><span class="coordinator-idea-code"><c:out value="${submission.idea_codigo}" /> · Idea: <c:out value="${submission.idea_titulo}" /></span><h2><c:out value="${submission.titulo}" /></h2></div>
                      <c:choose>
                        <c:when test="${not empty submission.proyecto_final_id and submission.proyecto_final_estado eq 'aplazado'}"><span class="my-idea-status my-idea-status-changes">Proyecto final aplazado por <c:choose><c:when test="${submission.proyecto_final_etapa eq 'evaluador'}">el evaluador</c:when><c:otherwise>el director</c:otherwise></c:choose></span></c:when>
                        <c:when test="${not empty submission.proyecto_final_id and submission.proyecto_final_estado eq 'rechazado'}"><span class="my-idea-status my-idea-status-rejected">Proyecto final rechazado por <c:choose><c:when test="${submission.proyecto_final_etapa eq 'evaluador'}">el evaluador</c:when><c:otherwise>el director</c:otherwise></c:choose></span></c:when>
                        <c:when test="${not empty submission.proyecto_final_id and submission.proyecto_final_estado eq 'pendiente_director'}"><span class="my-idea-status my-idea-status-pending">Proyecto final pendiente del director</span></c:when>
                        <c:when test="${not empty submission.proyecto_final_id and submission.proyecto_final_estado eq 'pendiente_evaluador'}"><span class="my-idea-status my-idea-status-pending">Proyecto final pendiente del evaluador</span></c:when>
                        <c:when test="${not empty submission.proyecto_final_id and submission.proyecto_final_estado eq 'aprobado'}"><span class="my-idea-status my-idea-status-approved">Proyecto final aprobado</span></c:when>
                        <c:when test="${submission.estado eq 'aprobado'}"><span class="my-idea-status my-idea-status-approved">Aprobado</span></c:when>
                        <c:when test="${submission.estado eq 'aplazado'}"><span class="my-idea-status my-idea-status-changes">Aplazado · requiere correcciones</span></c:when>
                        <c:when test="${submission.estado eq 'rechazado'}"><span class="my-idea-status my-idea-status-rejected">Rechazado</span></c:when>
                        <c:when test="${submission.estado eq 'pendiente_evaluador'}"><span class="my-idea-status my-idea-status-pending">Pendiente de evaluación</span></c:when>
                        <c:otherwise><span class="my-idea-status my-idea-status-pending">Pendiente de revisión del director</span></c:otherwise>
                      </c:choose>
                    </header>
                    <div class="coordinator-idea-meta">
                      <span><strong>Director</strong><c:out value="${submission.director}" /></span>
                      <c:if test="${not empty submission.evaluador}"><span><strong>Evaluador</strong><c:out value="${submission.evaluador}" /></span></c:if>
                      <c:if test="${not empty submission.integrante}"><span><strong>Compañero de proyecto</strong><c:out value="${submission.integrante}" /></span></c:if>
                      <span><strong>Enviado</strong><c:out value="${submission.enviado_en}" /></span>
                      <c:if test="${not empty submission.revisada_en}"><span><strong>Última revisión</strong><c:out value="${submission.revisada_en}" /></span></c:if>
                    </div>
                    <jsp:include page="/WEB-INF/project-phase-tracker.jsp"><jsp:param name="phase" value="${submission.fase_actual}" /><jsp:param name="requestState" value="${submission.solicitud_estado}" /></jsp:include>
                    <section class="coordinator-idea-description">
                      <h3>Información completa de la idea escogida</h3>
                      <div class="coordinator-idea-meta"><span><strong>Programa</strong><c:out value="${submission.idea_programa}" /></span><span><strong>Área temática</strong><c:out value="${submission.idea_area}" /></span></div>
                      <h3>Problema o necesidad</h3><p><c:out value="${submission.idea_problema}" /></p>
                      <h3>Descripción de la idea</h3><p><c:out value="${submission.idea_descripcion}" /></p>
                      <h3>Objetivos</h3><p><c:out value="${submission.idea_objetivos}" /></p>
                      <h3>Tecnologías o recursos</h3><p><c:out value="${submission.idea_recursos}" /></p>
                      <h3>Beneficiarios</h3><p><c:out value="${submission.idea_beneficiarios}" /></p>
                    </section>
                    <c:if test="${submission.estado eq 'aprobado' and empty submission.proyecto_final_id and submission.lider_id eq sessionScope.userId}">
                      <section class="coordinator-idea-description">
                        <h3>Fase 4 · Enviar proyecto final</h3>
                        <p>El título se conserva del anteproyecto aprobado. Comparte la descripción y el enlace del proyecto completo para enviarlo a revisión del director.</p>
                      </section>
                      <form class="teacher-idea-form final-project-submit-form" action="${anteproyectoUrl}" method="post">
                        <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="action" value="submitFinalProject"><input type="hidden" name="anteproyectoId" value="<c:out value='${submission.id}' />">
                        <label class="admin-field teacher-field-wide"><span>Descripción del proyecto <i>*</i></span><textarea name="description" maxlength="3000" rows="4" required></textarea></label>
                        <label class="admin-field teacher-field-wide"><span>Enlace al proyecto completo en Google Drive o Docs <i>*</i></span><input name="driveUrl" type="url" maxlength="500" placeholder="https://drive.google.com/..." required><small>Configura el acceso para que el director y el evaluador puedan consultarlo.</small></label>
                        <div class="teacher-idea-submit"><button class="button button-primary" type="submit">Enviar proyecto al director <span aria-hidden="true">→</span></button></div>
                      </form>
                    </c:if>
                    <c:if test="${not empty submission.proyecto_final_id}">
                      <section class="coordinator-idea-description">
                        <h3>Proyecto final · <c:out value="${submission.proyecto_final_titulo}" /></h3>
                        <p><c:out value="${submission.proyecto_final_descripcion}" /></p>
                      </section>
                      <div class="coordinator-idea-meta">
                        <span><strong>Estado del proyecto final</strong><c:choose><c:when test="${submission.proyecto_final_estado eq 'pendiente_director'}">Pendiente de aprobación del director</c:when><c:when test="${submission.proyecto_final_estado eq 'pendiente_evaluador'}">Pendiente de aprobación del evaluador</c:when><c:when test="${submission.proyecto_final_estado eq 'aprobado'}">Aprobado por director y evaluador</c:when><c:when test="${submission.proyecto_final_estado eq 'aplazado'}">Aplazado · requiere correcciones</c:when><c:otherwise>Rechazado por el <c:choose><c:when test="${submission.proyecto_final_etapa eq 'evaluador'}">evaluador</c:when><c:otherwise>director</c:otherwise></c:choose></c:otherwise></c:choose></span>
                        <span><strong>Enviado</strong><c:out value="${submission.proyecto_final_enviado_en}" /></span>
                        <c:if test="${not empty submission.proyecto_final_revisada_en}"><span><strong>Última revisión</strong><c:out value="${submission.proyecto_final_revisada_en}" /></span></c:if>
                      </div>
                      <a class="drive-link" href="<c:out value='${submission.proyecto_final_enlace}' />" target="_blank" rel="noopener noreferrer">Abrir proyecto final compartido <span aria-hidden="true">↗</span></a>
                      <c:if test="${not empty submission.proyecto_final_observaciones}"><div class="my-idea-feedback"><strong>Observaciones del <c:choose><c:when test="${submission.proyecto_final_etapa eq 'evaluador'}">evaluador</c:when><c:otherwise>director</c:otherwise></c:choose></strong><p><c:out value="${submission.proyecto_final_observaciones}" /></p></div></c:if>
                      <c:if test="${submission.proyecto_final_estado eq 'aplazado' and submission.lider_id eq sessionScope.userId}">
                        <form class="teacher-idea-form anteproject-resubmit-form" action="${anteproyectoUrl}" method="post">
                          <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="action" value="resubmitFinalProject"><input type="hidden" name="finalProjectId" value="<c:out value='${submission.proyecto_final_id}' />">
                          <h3>Corregir y reenviar el proyecto final</h3>
                          <label class="admin-field teacher-field-wide"><span>Descripción actualizada <i>*</i></span><textarea name="description" maxlength="3000" rows="3" required><c:out value="${submission.proyecto_final_descripcion}" /></textarea></label>
                          <label class="admin-field teacher-field-wide"><span>Nuevo enlace de Google Drive o Docs <i>*</i></span><input name="driveUrl" type="url" maxlength="500" placeholder="https://drive.google.com/..." required></label>
                          <div class="teacher-idea-submit"><button class="button button-primary" type="submit">Reenviar proyecto corregido <span aria-hidden="true">→</span></button></div>
                        </form>
                      </c:if>
                    </c:if>
                    <section class="coordinator-idea-description"><h3>Descripción</h3><p><c:out value="${submission.descripcion}" /></p></section>
                    <a class="drive-link" href="<c:out value='${submission.enlace_drive}' />" target="_blank" rel="noopener noreferrer">Abrir documento compartido <span aria-hidden="true">↗</span></a>
                    <c:if test="${not empty submission.observaciones}"><div class="my-idea-feedback"><strong>Observaciones del <c:choose><c:when test="${submission.etapa eq 'evaluador'}">evaluador</c:when><c:otherwise>director</c:otherwise></c:choose></strong><p><c:out value="${submission.observaciones}" /></p></div></c:if>
                    <c:if test="${submission.estado eq 'aplazado' and submission.lider_id eq sessionScope.userId}">
                      <form class="teacher-idea-form anteproject-resubmit-form" action="${anteproyectoUrl}" method="post">
                        <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="action" value="resubmit"><input type="hidden" name="anteproyectoId" value="<c:out value='${submission.id}' />">
                        <h3>Corregir y reenviar al mismo director</h3>
                        <label class="admin-field teacher-field-wide"><span>Descripción actualizada <i>*</i></span><textarea name="description" maxlength="3000" rows="3" required><c:out value="${submission.descripcion}" /></textarea></label>
                        <label class="admin-field teacher-field-wide"><span>Nuevo enlace de Google Drive o Docs <i>*</i></span><input name="driveUrl" type="url" maxlength="500" placeholder="https://drive.google.com/..." required></label>
                        <div class="teacher-idea-submit"><button class="button button-primary" type="submit">Reenviar para revisión <span aria-hidden="true">→</span></button></div>
                      </form>
                    </c:if>
                  </article>
                </c:forEach>
              </div>
            </c:otherwise>
          </c:choose>
        </section>
        <footer class="dashboard-footer"><span>Universitaria Tecnológica de Santander</span><span>Recuerda dar acceso de lectura a los documentos compartidos.</span></footer>
      </main>
    </section>
  </div>
</body>
</html>

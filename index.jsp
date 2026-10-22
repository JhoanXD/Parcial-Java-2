<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<c:choose>
  <c:when test="${empty sessionScope.userId}"><c:redirect url="/login.jsp" /></c:when>
  <c:otherwise>
    <sql:query var="activeUser" dataSource="jdbc/ProjectsDB">
      SELECT u.id,u.nombre_completo,r.nombre AS rol,e.programa_id
      FROM usuarios u JOIN usuario_roles ur ON ur.usuario_id=u.id JOIN roles r ON r.id=ur.rol_id
      LEFT JOIN estudiantes e ON e.usuario_id=u.id
      WHERE u.id=? AND u.estado='activo'
      ORDER BY CASE r.nombre WHEN 'administrador' THEN 1 WHEN 'coordinador' THEN 2 WHEN 'estudiante' THEN 3 ELSE 4 END LIMIT 1
      <sql:param value="${sessionScope.userId}" />
    </sql:query>
    <c:choose>
      <c:when test="${empty activeUser.rows}">
        <c:remove var="userId" scope="session" /><c:remove var="userName" scope="session" /><c:remove var="userRole" scope="session" />
        <c:redirect url="/login.jsp" />
      </c:when>
      <c:when test="${activeUser.rows[0].rol eq 'administrador'}"><c:redirect url="/admin-usuarios.jsp" /></c:when>
      <c:when test="${activeUser.rows[0].rol eq 'coordinador'}"><c:redirect url="/coordinador-ideas.jsp" /></c:when>
      <c:when test="${activeUser.rows[0].rol eq 'docente'}"><c:redirect url="/docente.jsp" /></c:when>
      <c:when test="${activeUser.rows[0].rol ne 'estudiante'}"><c:redirect url="/login.jsp" /></c:when>
      <c:otherwise><c:set var="currentUserName" value="${activeUser.rows[0].nombre_completo}" /></c:otherwise>
    </c:choose>
  </c:otherwise>
</c:choose>
<c:url var="stylesUrl" value="/assets/css/styles.css?v=20261016o" />
<c:url var="homeUrl" value="/index.jsp" />
<c:url var="ideasUrl" value="/banco-ideas.jsp" />
<c:url var="myIdeasUrl" value="/mis-ideas.jsp" />
<c:url var="proposalUrl" value="/crear-idea.jsp" />
<c:url var="anteproyectoUrl" value="/anteproyecto.jsp" />
<c:url var="requestsUrl" value="/solicitudes-ideas.jsp" />
<c:url var="loginUrl" value="/logout.jsp" />
<sql:query var="activeStudentProcess" dataSource="jdbc/ProjectsDB">
  SELECT s.id,s.estado,s.corregir_hasta,i.titulo
  FROM solicitudes_ideas s JOIN ideas i ON i.id=s.idea_id
  WHERE (s.estudiante_id=? OR s.integrante_id=?)
    AND (s.estado IN ('pendiente','aprobada') OR (s.estado='rechazada' AND s.corregir_hasta>NOW()))
    AND NOT EXISTS (
      SELECT 1 FROM anteproyectos completed_ap
      JOIN proyectos_finales completed_pf ON completed_pf.anteproyecto_id=completed_ap.id
      WHERE completed_ap.idea_id=s.idea_id AND completed_ap.estudiante_id=s.estudiante_id
        AND completed_pf.estado='aprobado'
    )
  ORDER BY s.creada_en DESC,s.id DESC LIMIT 1
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<sql:query var="completedStudentProjects" dataSource="jdbc/ProjectsDB">
  SELECT DISTINCT pf.id,pf.titulo AS proyecto_titulo,i.titulo AS idea_titulo,
    latest_review.revisada_en AS aprobado_en
  FROM proyectos_finales pf
  JOIN anteproyectos ap ON ap.id=pf.anteproyecto_id
  JOIN ideas i ON i.id=ap.idea_id
  LEFT JOIN solicitudes_ideas team_request ON team_request.idea_id=ap.idea_id
    AND team_request.estudiante_id=ap.estudiante_id AND team_request.estado='aprobada'
  JOIN revisiones_proyectos_finales latest_review ON latest_review.id=(
    SELECT MAX(review.id) FROM revisiones_proyectos_finales review WHERE review.proyecto_final_id=pf.id
  )
  WHERE pf.estado='aprobado'
    AND latest_review.etapa='evaluador' AND latest_review.decision='aprobado'
    AND (ap.estudiante_id=? OR team_request.integrante_id=?)
  ORDER BY latest_review.revisada_en DESC,pf.id DESC
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<sql:query var="studentDeadlines" dataSource="jdbc/ProjectsDB">
  SELECT plazo.tipo,plazo.titulo,plazo.fecha_limite,plazo.dias_restantes
  FROM (
    SELECT 'Anteproyecto' AS tipo,i.titulo,
      DATE_ADD(s.respondida_en,INTERVAL 6 MONTH) AS fecha_limite,
      DATEDIFF(DATE_ADD(s.respondida_en,INTERVAL 6 MONTH),CURDATE()) AS dias_restantes
    FROM solicitudes_ideas s
    JOIN ideas i ON i.id=s.idea_id
    WHERE (s.estudiante_id=? OR s.integrante_id=?)
      AND s.estado='aprobada' AND s.pago_verificado=1 AND s.respondida_en IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM anteproyectos ap
        WHERE ap.idea_id=s.idea_id AND ap.estudiante_id=s.estudiante_id
      )
    UNION ALL
    SELECT 'Proyecto final',i.titulo,
      DATE_ADD(ap.revisado_en,INTERVAL 6 MONTH),
      DATEDIFF(DATE_ADD(ap.revisado_en,INTERVAL 6 MONTH),CURDATE())
    FROM anteproyectos ap
    JOIN ideas i ON i.id=ap.idea_id
    JOIN solicitudes_ideas s ON s.idea_id=ap.idea_id AND s.estudiante_id=ap.estudiante_id
      AND s.estado='aprobada' AND s.pago_verificado=1
    LEFT JOIN solicitudes_ideas team_request ON team_request.idea_id=ap.idea_id
      AND team_request.estudiante_id=ap.estudiante_id AND team_request.estado='aprobada'
    WHERE (ap.estudiante_id=? OR team_request.integrante_id=?)
      AND ap.estado='aprobado' AND ap.revisado_en IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM proyectos_finales pf WHERE pf.anteproyecto_id=ap.id
      )
  ) plazo
  ORDER BY plazo.fecha_limite ASC
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<sql:query var="approvedTotal" dataSource="jdbc/ProjectsDB">
  SELECT COUNT(*) AS total
  FROM ideas i JOIN direcciones_ideas d ON d.idea_id=i.id
  WHERE i.estado='aprobada' AND i.programa_id=?
    AND (i.seleccionada_por IS NULL OR (i.seleccionada_hasta IS NOT NULL AND i.seleccionada_hasta<=NOW()))
    AND NOT EXISTS (
      SELECT 1 FROM proyectos_finales completed_pf
      JOIN anteproyectos completed_ap ON completed_ap.id=completed_pf.anteproyecto_id
      WHERE completed_ap.idea_id=i.id AND completed_pf.estado='aprobado'
    )
  <sql:param value="${activeUser.rows[0].programa_id}" />
</sql:query>
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#f5f7f6">
  <title>Inicio | Proyectos de grado UTS</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="${stylesUrl}">
</head>
<body>
  <div class="app-shell">
    <input class="sidebar-toggle" id="sidebarToggle" type="checkbox" aria-label="Mostrar menú">
    <aside class="sidebar">
      <a class="brand sidebar-brand" href="${homeUrl}" aria-label="UTS Proyectos de grado, inicio">
        <span class="brand-mark" aria-hidden="true"><span>U</span><span>T</span><span>S</span></span>
        <span class="brand-copy"><strong>UTS</strong><span>Proyectos de grado</span></span>
      </a>
      <div class="sidebar-label">MENÚ PRINCIPAL</div>
      <nav class="side-nav" aria-label="Menú principal">
        <a class="nav-link active" href="${homeUrl}" aria-current="page">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="m3.5 10 8.5-7 8.5 7v9a1.5 1.5 0 0 1-1.5 1.5h-14A1.5 1.5 0 0 1 3.5 19v-9Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M9 20.5v-7h6v7" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/></svg>
          Inicio
        </a>
        <a class="nav-link" href="${ideasUrl}">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M9 18h6m-5 3h4m-2-19a7 7 0 0 0-4.2 12.6c.8.6 1.2 1.3 1.2 2.4h6c0-1.1.4-1.8 1.2-2.4A7 7 0 0 0 12 2Z" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>
          Banco de ideas
        </a>
        <a class="nav-link" href="${proposalUrl}">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 5v14m-7-7h14" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.7"/></svg>
          Proponer una idea
        </a>
        <a class="nav-link" href="${myIdeasUrl}">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5" stroke="currentColor" stroke-width="1.7"/><path d="M8 5V3.5h8V5m-12.5 5h17m-13 4h4m-4 3h8" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round" stroke-linecap="round"/></svg>
          Mis ideas
        </a>
        <a class="nav-link" href="${anteproyectoUrl}">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M5 3.5h9l5 5v12H5v-17Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M14 3.5v5h5M8 13h8m-8 3.5h8" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>
          Mis anteproyectos
        </a>
        <a class="nav-link" href="${requestsUrl}">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5" stroke="currentColor" stroke-width="1.7"/><path d="M8 5V3.5h8V5m-12.5 5h17m-13 4h4m-4 3h8" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round" stroke-linecap="round"/></svg>
          Mis solicitudes
        </a>
        <a class="nav-link" href="https://www.uts.edu.co/calendario-academico/" target="_blank" rel="noopener noreferrer">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5" stroke="currentColor" stroke-width="1.7"/><path d="M7.5 3.5v3m9-3v3m-13 3h17m-13 4h3m3 0h3m-9 3.5h3" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>
          Calendario académico <span aria-hidden="true">↗</span>
        </a>
      </nav>
      <div class="sidebar-bottom">
        <div class="help-card">
          <span class="help-icon"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.7"/><path d="M9.5 9a2.6 2.6 0 1 1 4.6 1.7c-.9 1-2.1 1.1-2.1 2.8m0 3h.01" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg></span>
          <strong>¿Necesitas ayuda?</strong><span>Estamos para acompañarte.</span>
          <span class="help-coming-soon">Soporte disponible próximamente</span>
        </div>
        <div class="sidebar-version">PLATAFORMA DE PROYECTOS <span>v1.0</span></div>
      </div>
    </aside>
    <label class="sidebar-overlay" for="sidebarToggle" aria-label="Cerrar menú"></label>

    <section class="main-area">
      <header class="topbar">
        <label class="mobile-menu" for="sidebarToggle" aria-label="Abrir menú">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
        </label>
        <div class="breadcrumb"><span>Estudiante</span><span class="crumb-slash">/</span><strong>Inicio</strong></div>
        <div class="topbar-actions">
          <span class="demo-badge"><i></i> PORTAL ESTUDIANTIL</span>
          <details class="notification-menu">
            <summary class="notification-button" aria-label="Ver plazos y notificaciones">
              <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M18 9a6 6 0 0 0-12 0c0 7-2.5 7-2.5 9h17C20.5 16 18 16 18 9Zm-8 12h4" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>
              <c:if test="${not empty studentDeadlines.rows or not empty completedStudentProjects.rows}"><span class="notification-count"><c:out value="${fn:length(studentDeadlines.rows) + fn:length(completedStudentProjects.rows)}" /></span></c:if>
            </summary>
            <div class="notification-panel" role="region" aria-label="Plazos y notificaciones de proyectos">
              <strong class="notification-panel-title">Plazos y notificaciones</strong>
              <c:choose>
                <c:when test="${empty studentDeadlines.rows and empty completedStudentProjects.rows}"><p class="notification-empty">No tienes plazos de entrega activos.</p></c:when>
                <c:otherwise>
                  <c:forEach var="completedProject" items="${completedStudentProjects.rows}">
                    <article class="notification-deadline notification-completed">
                      <strong>¡Proyecto aprobado!</strong>
                      <span class="notification-project-title"><c:out value="${completedProject.proyecto_titulo}" /> · <c:out value="${completedProject.idea_titulo}" /></span>
                      <span>¡Felicidades! Tu proyecto fue aprobado. Ya te puedes graduar.</span>
                      <small>Aprobado: <c:out value="${completedProject.aprobado_en}" /></small>
                    </article>
                  </c:forEach>
                  <c:forEach var="deadline" items="${studentDeadlines.rows}">
                    <article class="notification-deadline">
                      <strong><c:out value="${deadline.tipo}" /></strong>
                      <span class="notification-project-title"><c:out value="${deadline.titulo}" /></span>
                      <c:choose>
                        <c:when test="${deadline.dias_restantes gt 1}"><span>Te quedan <c:out value="${deadline.dias_restantes}" /> días para presentar.</span></c:when>
                        <c:when test="${deadline.dias_restantes eq 1}"><span>Te queda 1 día para presentar.</span></c:when>
                        <c:when test="${deadline.dias_restantes eq 0}"><span class="notification-deadline-urgent">El plazo vence hoy.</span></c:when>
                        <c:otherwise><span class="notification-deadline-urgent">El plazo venció hace <c:out value="${0 - deadline.dias_restantes}" /> días.</span></c:otherwise>
                      </c:choose>
                      <small>Fecha límite: <c:out value="${deadline.fecha_limite}" /></small>
                    </article>
                  </c:forEach>
                </c:otherwise>
              </c:choose>
              <a class="notification-panel-link" href="${anteproyectoUrl}">Ver seguimiento de proyectos</a>
            </div>
          </details>
          <span class="topbar-divider"></span>
          <a class="profile-button" href="${loginUrl}" aria-label="Cerrar sesión" title="Cerrar sesión">
            <span class="avatar"><c:out value="${fn:toUpperCase(fn:substring(currentUserName, 0, 1))}" /></span><span class="profile-info"><strong><c:out value="${currentUserName}" /></strong><small>Estudiante · Cerrar sesión</small></span>
            <svg class="profile-chevron" viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="m7 10 5 5 5-5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>
          </a>
        </div>
      </header>

      <main class="dashboard">
        <div class="greeting-row">
          <div><p class="date-label">TU ESPACIO ACADÉMICO</p><h1>¡Hola, <c:out value="${currentUserName}" />! <span aria-hidden="true">✳</span></h1><p class="greeting-copy">¿Listo para convertir una idea en tu próximo gran proyecto?</p></div>
          <span class="semester-label"><span></span> PERIODO 2026</span>
        </div>
        <c:if test="${not empty activeStudentProcess.rows}">
          <div class="admin-alert" role="status"><strong>Tienes un proceso de idea activo.</strong><span><c:out value="${activeStudentProcess.rows[0].titulo}" /> sigue en revisión o ya fue asignada. No puedes proponer ni solicitar otra idea mientras este proceso esté activo; consulta <a href="${requestsUrl}">Mis solicitudes</a>.</span></div>
        </c:if>
        <c:if test="${not empty completedStudentProjects.rows}">
          <div class="admin-alert admin-alert-success" role="status"><strong>¡Felicidades!</strong><span>Tu proyecto fue aprobado. ¡Ya te puedes graduar!</span></div>
        </c:if>

        <section class="welcome-banner" aria-labelledby="welcomeTitle">
          <div class="welcome-copy">
            <span class="banner-eyebrow"><span></span> EL PRIMER PASO EMPIEZA AQUÍ</span>
            <h2 id="welcomeTitle">Tu proyecto de grado<br>empieza con una <em>idea.</em></h2>
            <p>Explora propuestas aprobadas por la coordinación o atrévete a plantear una propia.</p>
            <a class="button button-light" href="${ideasUrl}">Explorar ideas aprobadas <span aria-hidden="true">→</span></a>
          </div>
          <div class="welcome-art" aria-hidden="true">
            <div class="banner-circle circle-large"></div><div class="banner-circle circle-small"></div>
            <div class="banner-spark spark-a">✳</div><div class="banner-spark spark-b">✦</div>
            <div class="banner-stamp"><span>IDEAS QUE</span><strong>TRANSFORMAN</strong><i>UTS · 2026</i></div>
            <div class="banner-orbit"></div>
          </div>
        </section>

        <section class="quick-stats" aria-label="Resumen académico">
          <article class="stat-card">
            <span class="stat-icon icon-green"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M9 18h6m-5 3h4m-2-19a7 7 0 0 0-4.2 12.6c.8.6 1.2 1.3 1.2 2.4h6c0-1.1.4-1.8 1.2-2.4A7 7 0 0 0 12 2Z" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg></span>
            <span class="stat-label">Ideas disponibles</span><strong class="stat-value"><c:out value="${approvedTotal.rows[0].total}" /></strong><span class="stat-foot">Aprobadas para estudiantes</span>
          </article>
          <article class="stat-card stat-action">
            <span class="stat-icon icon-peach"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 5v14m-7-7h14" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.7"/></svg></span>
            <span class="stat-label"><c:choose><c:when test="${not empty activeStudentProcess.rows}">Proceso en curso</c:when><c:otherwise>¿Tienes una idea propia?</c:otherwise></c:choose></span><strong class="stat-cta"><c:choose><c:when test="${not empty activeStudentProcess.rows}">Ya tienes una idea</c:when><c:otherwise>Propón tu proyecto</c:otherwise></c:choose></strong><c:if test="${empty activeStudentProcess.rows}"><a class="stat-link" href="${proposalUrl}">Cuéntanos de qué se trata <span aria-hidden="true">→</span></a></c:if>
          </article>
        </section>

        <footer class="dashboard-footer"><span>Universitaria Tecnológica de Santander</span><span>Banco de ideas actualizado con propuestas aprobadas.</span></footer>
      </main>
    </section>
  </div>

</body>
</html>

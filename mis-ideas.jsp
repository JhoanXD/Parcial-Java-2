<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<c:choose>
  <c:when test="${empty sessionScope.userId}"><c:redirect url="/login.jsp" /></c:when>
  <c:otherwise>
    <sql:query var="activeUser" dataSource="jdbc/ProjectsDB">
      SELECT u.id,u.nombre_completo,r.nombre AS rol
      FROM usuarios u JOIN usuario_roles ur ON ur.usuario_id=u.id JOIN roles r ON r.id=ur.rol_id
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
    </c:choose>
  </c:otherwise>
</c:choose>
<c:url var="stylesUrl" value="/assets/css/styles.css?v=20261021b" />
<c:url var="homeUrl" value="/index.jsp" />
<c:url var="ideasUrl" value="/banco-ideas.jsp" />
<c:url var="myIdeasUrl" value="/mis-ideas.jsp" />
<c:url var="proposalUrl" value="/crear-idea.jsp" />
<c:url var="anteproyectoUrl" value="/anteproyecto.jsp" />
<c:url var="requestsUrl" value="/solicitudes-ideas.jsp" />
<c:url var="logoutUrl" value="/logout.jsp" />
<sql:query var="activeStudentProcess" dataSource="jdbc/ProjectsDB">
  SELECT s.id,s.estado,i.titulo
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
<sql:query var="myIdeas" dataSource="jdbc/ProjectsDB">
  SELECT i.codigo,i.titulo,i.problema,i.descripcion,i.estado,i.enviada_en,i.revisada_en,
    p.nombre AS programa,a.nombre AS area,r.decision,r.observaciones,r.revisada_en AS decision_fecha,
    reviewer.nombre_completo AS coordinador,partner.nombre_completo AS integrante
  FROM ideas i
  JOIN programas_academicos p ON p.id=i.programa_id
  JOIN areas_tematicas a ON a.id=i.area_id
  LEFT JOIN revisiones_ideas r ON r.id=(
    SELECT MAX(latest.id) FROM revisiones_ideas latest WHERE latest.idea_id=i.id
  )
  LEFT JOIN usuarios reviewer ON reviewer.id=r.revisor_id
  LEFT JOIN solicitudes_ideas student_request ON student_request.idea_id=i.id AND student_request.estudiante_id=i.proponente_id
    AND student_request.estado IN ('pendiente','aprobada','retirada','rechazada')
  LEFT JOIN usuarios partner ON partner.id=student_request.integrante_id
  WHERE i.proponente_id=? AND i.tipo='estudiantil'
    AND NOT EXISTS (
      SELECT 1 FROM proyectos_finales completed_pf
      JOIN anteproyectos completed_ap ON completed_ap.id=completed_pf.anteproyecto_id
      WHERE completed_ap.idea_id=i.id AND completed_pf.estado='aprobado'
    )
  ORDER BY i.creada_en DESC,i.id DESC
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="theme-color" content="#f5f7f6">
  <title>Mis ideas | Proyectos de grado UTS</title>
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
        <a class="nav-link" href="${homeUrl}">
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
        <a class="nav-link active" href="${myIdeasUrl}" aria-current="page">
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
      <div class="sidebar-bottom"><div class="sidebar-version">PLATAFORMA DE PROYECTOS <span>v1.0</span></div></div>
    </aside>
    <label class="sidebar-overlay" for="sidebarToggle" aria-label="Cerrar menú"></label>
    <section class="main-area">
      <header class="topbar">
        <label class="mobile-menu" for="sidebarToggle" aria-label="Abrir menú"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg></label>
        <div class="breadcrumb"><a href="${homeUrl}">Estudiante</a><span class="crumb-slash">/</span><strong>Mis ideas</strong></div>
        <div class="topbar-actions"><span class="demo-badge"><i></i> PORTAL ESTUDIANTIL</span><span class="topbar-divider"></span><a class="profile-button" href="${logoutUrl}"><span class="avatar"><c:out value="${fn:toUpperCase(fn:substring(activeUser.rows[0].nombre_completo,0,1))}" /></span><span class="profile-info"><strong><c:out value="${activeUser.rows[0].nombre_completo}" /></strong><small>Estudiante · Cerrar sesión</small></span></a></div>
      </header>
      <main class="dashboard student-section-page">
        <header class="student-page-heading">
          <div><p class="section-overline"><span></span> SEGUIMIENTO DE PROPUESTAS</p><h1>Mis ideas <span class="ideas-count"><c:out value="${fn:length(myIdeas.rows)}" /></span></h1><p>Consulta el estado y las observaciones de coordinación sobre tus propuestas.</p></div>
          <c:if test="${empty activeStudentProcess.rows}"><a class="button button-primary" href="${proposalUrl}">Proponer una idea <span aria-hidden="true">→</span></a></c:if>
        </header>
        <c:choose>
          <c:when test="${empty myIdeas.rows}">
            <div class="my-ideas-empty"><strong>Aún no has enviado ideas.</strong><span>Cuando envíes una propuesta, aquí podrás seguir su revisión.</span><c:if test="${empty activeStudentProcess.rows}"><a href="${proposalUrl}">Crear mi primera propuesta <span aria-hidden="true">→</span></a></c:if></div>
          </c:when>
          <c:otherwise>
            <div class="my-ideas-list">
              <c:forEach var="myIdea" items="${myIdeas.rows}">
                <article class="my-idea-card">
                  <div class="my-idea-card-heading">
                    <div><span class="my-idea-code"><c:out value="${myIdea.codigo}" /></span><h3><c:out value="${myIdea.titulo}" /></h3></div>
                    <c:choose>
                      <c:when test="${myIdea.estado eq 'aprobada'}"><span class="my-idea-status my-idea-status-approved">Aprobada</span></c:when>
                      <c:when test="${myIdea.estado eq 'rechazada'}"><span class="my-idea-status my-idea-status-rejected">Rechazada</span></c:when>
                      <c:when test="${myIdea.estado eq 'requiere_ajustes'}"><span class="my-idea-status my-idea-status-changes">Requiere ajustes</span></c:when>
                      <c:when test="${myIdea.estado eq 'en_revision'}"><span class="my-idea-status my-idea-status-review">En revisión</span></c:when>
                      <c:otherwise><span class="my-idea-status my-idea-status-pending">Pendiente de revisión</span></c:otherwise>
                    </c:choose>
                  </div>
                  <p class="my-idea-description"><c:out value="${myIdea.descripcion}" /></p>
                  <div class="my-idea-meta"><span><strong>Programa</strong><c:out value="${myIdea.programa}" /></span><span><strong>Área</strong><c:out value="${myIdea.area}" /></span>
                    <c:if test="${not empty myIdea.integrante}"><span><strong>Compañero de proyecto</strong><c:out value="${myIdea.integrante}" /></span></c:if>
                    <c:if test="${not empty myIdea.decision_fecha}"><span><strong>Revisada</strong><c:out value="${myIdea.decision_fecha}" /></span></c:if>
                  </div>
                  <c:if test="${not empty myIdea.observaciones}"><div class="my-idea-feedback"><strong>Observaciones de coordinación</strong><p><c:out value="${myIdea.observaciones}" /></p><c:if test="${not empty myIdea.coordinador}"><small><c:out value="${myIdea.coordinador}" /></small></c:if></div></c:if>
                </article>
              </c:forEach>
            </div>
          </c:otherwise>
        </c:choose>
        <footer class="dashboard-footer"><span>Universitaria Tecnológica de Santander</span><span>Seguimiento de tus propuestas de proyecto.</span></footer>
      </main>
    </section>
  </div>
</body>
</html>

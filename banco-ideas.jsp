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
<c:set var="searchTerm" value="${empty param.q ? '' : fn:toLowerCase(fn:trim(param.q))}" />
<c:set var="searchPattern" value="%${searchTerm}%" />
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
<sql:query var="approvedIdeas" dataSource="jdbc/ProjectsDB">
  SELECT v.id,v.codigo,v.titulo,v.problema,v.descripcion,v.recursos_tecnologias,v.programa,v.area,v.proponente,
    director.nombre_completo AS director,evaluator.nombre_completo AS evaluador
  FROM ideas_aprobadas v
  JOIN ideas i ON i.id=v.id
  JOIN direcciones_ideas d ON d.idea_id=i.id
  JOIN usuarios director ON director.id=d.director_id
  LEFT JOIN evaluadores_ideas ei ON ei.idea_id=i.id
  LEFT JOIN usuarios evaluator ON evaluator.id=ei.evaluador_id
  WHERE v.programa_id=? AND (i.seleccionada_por IS NULL OR (i.seleccionada_hasta IS NOT NULL AND i.seleccionada_hasta<=NOW()))
    AND NOT EXISTS (
      SELECT 1 FROM proyectos_finales completed_pf
      JOIN anteproyectos completed_ap ON completed_ap.id=completed_pf.anteproyecto_id
      WHERE completed_ap.idea_id=i.id AND completed_pf.estado='aprobado'
    )
    AND (v.titulo LIKE ? OR v.problema LIKE ? OR v.descripcion LIKE ? OR COALESCE(v.recursos_tecnologias,'') LIKE ?
      OR v.programa LIKE ? OR v.area LIKE ? OR v.proponente LIKE ? OR director.nombre_completo LIKE ?)
  ORDER BY v.aprobada_en DESC,v.codigo
  <sql:param value="${activeUser.rows[0].programa_id}" />
  <sql:param value="${searchPattern}" />
  <sql:param value="${searchPattern}" />
  <sql:param value="${searchPattern}" />
  <sql:param value="${searchPattern}" />
  <sql:param value="${searchPattern}" />
  <sql:param value="${searchPattern}" />
  <sql:param value="${searchPattern}" />
  <sql:param value="${searchPattern}" />
</sql:query>
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="theme-color" content="#f5f7f6">
  <title>Banco de ideas | Proyectos de grado UTS</title>
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
        <a class="nav-link active" href="${ideasUrl}" aria-current="page">
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
      <div class="sidebar-bottom"><div class="sidebar-version">PLATAFORMA DE PROYECTOS <span>v1.0</span></div></div>
    </aside>
    <label class="sidebar-overlay" for="sidebarToggle" aria-label="Cerrar menú"></label>
    <section class="main-area">
      <header class="topbar">
        <label class="mobile-menu" for="sidebarToggle" aria-label="Abrir menú"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg></label>
        <div class="breadcrumb"><a href="${homeUrl}">Estudiante</a><span class="crumb-slash">/</span><strong>Banco de ideas</strong></div>
        <div class="topbar-actions"><span class="demo-badge"><i></i> PORTAL ESTUDIANTIL</span><span class="topbar-divider"></span><a class="profile-button" href="${logoutUrl}"><span class="avatar"><c:out value="${fn:toUpperCase(fn:substring(activeUser.rows[0].nombre_completo,0,1))}" /></span><span class="profile-info"><strong><c:out value="${activeUser.rows[0].nombre_completo}" /></strong><small>Estudiante · Cerrar sesión</small></span></a></div>
      </header>
      <main class="dashboard student-section-page">
        <header class="student-page-heading">
          <div><p class="section-overline"><span></span> INSPÍRATE Y ENCUENTRA LA TUYA</p><h1>Banco de ideas <span class="ideas-count"><c:out value="${approvedTotal.rows[0].total}" /></span></h1><p>Explora las propuestas aprobadas disponibles para tu programa académico.</p></div>
          <form class="ideas-tools" action="${ideasUrl}" method="get">
            <label class="search-box" for="ideaSearch"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><circle cx="10.8" cy="10.8" r="6.8" stroke="currentColor" stroke-width="1.7"/><path d="m16 16 4.5 4.5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg><input id="ideaSearch" name="q" type="search" placeholder="Buscar una idea..." value="<c:out value='${param.q}' />"></label>
            <button class="filter-button" type="submit"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 6h16M7 12h10m-7 6h4" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg><span>Buscar</span></button>
          </form>
        </header>
        <c:if test="${not empty activeStudentProcess.rows}"><div class="admin-alert" role="status"><strong>Tienes un proceso de idea activo.</strong><span>Completa la revisión de <c:out value="${activeStudentProcess.rows[0].titulo}" /> antes de solicitar otra idea. Consulta el avance en <a href="${requestsUrl}">Mis solicitudes</a>.</span></div></c:if>
        <section class="ideas-section" aria-label="Ideas aprobadas">
          <div class="ideas-grid" id="ideasGrid">
            <c:forEach var="idea" items="${approvedIdeas.rows}">
              <article class="idea-card">
                <div class="idea-card-top"><span class="idea-category category-green"><c:out value="${idea.area}" /></span><span class="idea-approved-label">APROBADA</span></div>
                <h3><c:out value="${idea.titulo}" /></h3>
                <p class="idea-description"><c:out value="${idea.descripcion}" /></p>
                <div class="idea-meta"><span class="teacher-avatar teacher-a"><c:out value="${fn:toUpperCase(fn:substring(idea.proponente,0,1))}" /></span><span><small>PROPUESTA POR</small><strong><c:out value="${idea.proponente}" /></strong></span><span class="idea-area"><c:out value="${idea.programa}" /></span></div>
                <div class="idea-director"><span>Director</span><strong><c:out value="${idea.director}" /></strong></div>
                <c:if test="${not empty idea.evaluador}"><div class="idea-director"><span>Evaluador</span><strong><c:out value="${idea.evaluador}" /></strong></div></c:if>
                <details class="idea-details"><summary>Conocer la idea <span aria-hidden="true">↗</span></summary><p><c:out value="${idea.problema}" /><c:if test="${not empty idea.recursos_tecnologias}"> Recursos sugeridos: <c:out value="${idea.recursos_tecnologias}" /></c:if></p></details>
                <c:url var="selectIdeaUrl" value="/solicitudes-ideas.jsp"><c:param name="ideaId" value="${idea.id}" /></c:url>
                <c:choose><c:when test="${empty activeStudentProcess.rows}"><a class="button button-primary idea-select-button" href="${selectIdeaUrl}">Solicitar esta idea <span aria-hidden="true">→</span></a></c:when><c:otherwise><span class="my-idea-status my-idea-status-pending">No disponible: ya tienes un proceso activo</span></c:otherwise></c:choose>
              </article>
            </c:forEach>
          </div>
          <c:if test="${empty approvedIdeas.rows}"><p class="no-results"><c:choose><c:when test="${approvedTotal.rows[0].total eq 0}">Todavía no hay ideas aprobadas para tu programa.</c:when><c:otherwise>No encontramos ideas con esa búsqueda. Prueba con otras palabras.</c:otherwise></c:choose></p></c:if>
          <div class="ideas-footer"><span>Solo se muestran propuestas aprobadas por coordinación.</span></div>
        </section>
        <footer class="dashboard-footer"><span>Universitaria Tecnológica de Santander</span><span>Banco de ideas actualizado con propuestas aprobadas.</span></footer>
      </main>
    </section>
  </div>
</body>
</html>

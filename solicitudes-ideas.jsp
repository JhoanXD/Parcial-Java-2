<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<c:choose>
  <c:when test="${empty sessionScope.userId}"><c:redirect url="/login.jsp" /></c:when>
  <c:otherwise>
    <sql:query var="activeStudent" dataSource="jdbc/ProjectsDB">
      SELECT u.id,u.nombre_completo,r.nombre AS rol,e.programa_id
      FROM usuarios u
      JOIN usuario_roles ur ON ur.usuario_id=u.id
      JOIN roles r ON r.id=ur.rol_id
      LEFT JOIN estudiantes e ON e.usuario_id=u.id
      WHERE u.id=? AND u.estado='activo'
      ORDER BY CASE r.nombre WHEN 'administrador' THEN 1 WHEN 'coordinador' THEN 2 WHEN 'docente' THEN 3 ELSE 4 END
      LIMIT 1
      <sql:param value="${sessionScope.userId}" />
    </sql:query>
    <c:choose>
      <c:when test="${empty activeStudent.rows}">
        <c:remove var="userId" scope="session" /><c:remove var="userName" scope="session" /><c:remove var="userRole" scope="session" />
        <c:redirect url="/login.jsp" />
      </c:when>
      <c:when test="${activeStudent.rows[0].rol eq 'administrador'}"><c:redirect url="/admin-usuarios.jsp" /></c:when>
      <c:when test="${activeStudent.rows[0].rol eq 'coordinador'}"><c:redirect url="/coordinador-ideas.jsp" /></c:when>
      <c:when test="${activeStudent.rows[0].rol eq 'docente'}"><c:redirect url="/docente.jsp" /></c:when>
      <c:when test="${activeStudent.rows[0].rol ne 'estudiante' or empty activeStudent.rows[0].programa_id}"><c:redirect url="/login.jsp" /></c:when>
      <c:otherwise><c:set var="currentUserName" value="${activeStudent.rows[0].nombre_completo}" /></c:otherwise>
    </c:choose>
  </c:otherwise>
</c:choose>
<c:if test="${empty sessionScope.csrfToken}">
  <sql:query var="newCsrf" dataSource="jdbc/ProjectsDB">SELECT LOWER(SHA2(CONCAT(UUID(),RAND(),UUID(),NOW(6)),256)) AS token</sql:query>
  <c:set var="csrfToken" value="${newCsrf.rows[0].token}" scope="session" />
</c:if>
<c:url var="requestsUrl" value="/solicitudes-ideas.jsp" />
<c:url var="proposalUrl" value="/crear-idea.jsp" />
<sql:query var="activeStudentProcess" dataSource="jdbc/ProjectsDB">
  SELECT s.id,s.estado,s.corregir_hasta,i.titulo
  FROM solicitudes_ideas s JOIN ideas i ON i.id=s.idea_id
  WHERE (s.estudiante_id=? OR s.integrante_id=?)
    AND (s.estado IN ('pendiente','aprobada') OR (s.estado='rechazada' AND s.corregir_hasta>NOW()))
  ORDER BY s.creada_en DESC,s.id DESC LIMIT 1
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<sql:query var="partnerCandidate" dataSource="jdbc/ProjectsDB">
  SELECT e.usuario_id,e.programa_id,u.nombre_completo,e.codigo_estudiantil
  FROM estudiantes e
  JOIN usuarios u ON u.id=e.usuario_id AND u.estado='activo'
  JOIN usuario_roles ur ON ur.usuario_id=u.id
  JOIN roles r ON r.id=ur.rol_id AND r.nombre='estudiante'
  WHERE e.codigo_estudiantil=? AND e.usuario_id<>? AND e.programa_id=?
  <sql:param value="${fn:trim(param.partnerCode)}" />
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${activeStudent.rows[0].programa_id}" />
</sql:query>
<c:set var="partnerId" value="${empty partnerCandidate.rows ? sessionScope.userId : partnerCandidate.rows[0].usuario_id}" />
<c:if test="${pageContext.request.method eq 'POST'}">
  <c:choose>
    <c:when test="${empty sessionScope.csrfToken or empty param.csrfToken or sessionScope.csrfToken ne param.csrfToken}">
      <c:set var="flashError" value="El formulario expiró. Recarga la página e inténtalo de nuevo." scope="session" />
    </c:when>
    <c:when test="${param.action eq 'request' and not empty fn:trim(param.partnerCode) and empty partnerCandidate.rows}">
      <c:set var="flashError" value="El código del compañero no corresponde a un estudiante activo de tu mismo programa." scope="session" />
    </c:when>
    <c:when test="${(param.action eq 'request' and empty param.ideaId) or ((param.action eq 'correct' or param.action eq 'cancel') and empty param.requestId) or (param.action ne 'request' and param.action ne 'correct' and param.action ne 'cancel') or (param.action eq 'cancel' and param.confirmCancel ne 'yes') or (param.action ne 'cancel' and (empty fn:trim(param.receiptUrl) or fn:length(fn:trim(param.receiptUrl)) gt 500 or (not fn:startsWith(fn:toLowerCase(fn:trim(param.receiptUrl)),'https://drive.google.com/') and not fn:startsWith(fn:toLowerCase(fn:trim(param.receiptUrl)),'https://docs.google.com/')) or fn:length(param.message) gt 800))}">
      <c:set var="flashError" value="Pega un enlace válido de Google Drive o Docs para el PDF del pago y verifica el límite de caracteres." scope="session" />
    </c:when>
    <c:otherwise>
      <c:choose>
        <c:when test="${param.action eq 'cancel'}">
          <c:set var="canceledRequest" value="0" />
          <c:catch var="requestFailure">
            <sql:transaction dataSource="jdbc/ProjectsDB">
              <sql:query var="studentLock">
                SELECT usuario_id FROM estudiantes WHERE usuario_id=? FOR UPDATE
                <sql:param value="${sessionScope.userId}" />
              </sql:query>
              <sql:query var="requestToCancel">
                SELECT s.id,s.idea_id FROM solicitudes_ideas s
                JOIN ideas i ON i.id=s.idea_id
                WHERE s.id=? AND s.estudiante_id=? AND s.estado IN ('pendiente','aprobada','rechazada')
                  AND i.seleccionada_por=s.estudiante_id
                FOR UPDATE
                <sql:param value="${param.requestId}" />
                <sql:param value="${sessionScope.userId}" />
              </sql:query>
              <c:if test="${not empty studentLock.rows and not empty requestToCancel.rows}">
                <sql:update var="canceledRequest">
                  UPDATE solicitudes_ideas
                  SET estado='retirada',corregir_hasta=NULL,
                      respondida_por=CASE WHEN pago_verificado=0 THEN NULL ELSE respondida_por END,
                      respondida_en=CASE WHEN pago_verificado=0 THEN NULL ELSE respondida_en END
                  WHERE id=? AND estudiante_id=? AND estado IN ('pendiente','aprobada','rechazada')
                  <sql:param value="${param.requestId}" />
                  <sql:param value="${sessionScope.userId}" />
                </sql:update>
                <c:if test="${canceledRequest eq 1}">
                  <sql:update>
                    UPDATE ideas SET seleccionada_por=NULL,seleccionada_hasta=NULL
                    WHERE id=? AND seleccionada_por=?
                    <sql:param value="${requestToCancel.rows[0].idea_id}" />
                    <sql:param value="${sessionScope.userId}" />
                  </sql:update>
                </c:if>
              </c:if>
            </sql:transaction>
          </c:catch>
        </c:when>
        <c:when test="${param.action eq 'correct'}">
          <c:catch var="requestFailure">
            <sql:transaction dataSource="jdbc/ProjectsDB">
              <sql:query var="studentLock">
                SELECT usuario_id FROM estudiantes WHERE usuario_id=? FOR UPDATE
                <sql:param value="${sessionScope.userId}" />
              </sql:query>
              <sql:update var="renewedRequest">
                UPDATE solicitudes_ideas s
                JOIN ideas i ON i.id=s.idea_id
                SET s.comprobante_pago_url=?,s.mensaje=NULLIF(?,''),s.estado='pendiente',s.pago_verificado=0,s.corregir_hasta=NULL
                WHERE s.id=? AND s.estudiante_id=? AND s.estado='rechazada'
                  AND s.corregir_hasta>NOW() AND i.seleccionada_por=s.estudiante_id
                  AND i.seleccionada_hasta=s.corregir_hasta
                <sql:param value="${fn:trim(param.receiptUrl)}" />
                <sql:param value="${fn:trim(param.message)}" />
                <sql:param value="${param.requestId}" />
                <sql:param value="${sessionScope.userId}" />
              </sql:update>
              <c:if test="${renewedRequest eq 1}">
                <sql:update>
                  UPDATE ideas SET seleccionada_hasta=NULL
                  WHERE seleccionada_por=? AND seleccionada_hasta IS NOT NULL
                    AND id=(SELECT idea_id FROM solicitudes_ideas WHERE id=?)
                  <sql:param value="${sessionScope.userId}" />
                  <sql:param value="${param.requestId}" />
                </sql:update>
              </c:if>
            </sql:transaction>
          </c:catch>
        </c:when>
        <c:otherwise>
          <c:set var="reservedIdea" value="0" />
          <c:set var="anotherActiveProcess" value="false" />
          <c:catch var="requestFailure">
            <sql:transaction dataSource="jdbc/ProjectsDB">
              <sql:query var="studentLock">
                SELECT usuario_id FROM estudiantes WHERE usuario_id=? OR usuario_id=? ORDER BY usuario_id FOR UPDATE
                <sql:param value="${sessionScope.userId}" />
                <sql:param value="${partnerId}" />
              </sql:query>
              <sql:query var="activeProcess">
                SELECT id,estado FROM solicitudes_ideas
                WHERE (estudiante_id=? OR integrante_id=? OR estudiante_id=? OR integrante_id=?)
                  AND (estado IN ('pendiente','aprobada') OR (estado='rechazada' AND corregir_hasta>NOW()))
                LIMIT 1
                <sql:param value="${sessionScope.userId}" />
                <sql:param value="${sessionScope.userId}" />
                <sql:param value="${partnerId}" />
                <sql:param value="${partnerId}" />
              </sql:query>
              <c:if test="${not empty activeProcess.rows}">
                <c:set var="anotherActiveProcess" value="true" />
              </c:if>
              <c:if test="${empty activeProcess.rows and not empty studentLock.rows}">
                <sql:update>
                  UPDATE ideas SET seleccionada_por=NULL,seleccionada_hasta=NULL
                  WHERE seleccionada_por=? AND seleccionada_hasta IS NOT NULL AND seleccionada_hasta<=NOW()
                  <sql:param value="${sessionScope.userId}" />
                </sql:update>
                <sql:update var="reservedIdea">
                  UPDATE ideas
                  SET seleccionada_por=?,seleccionada_hasta=NULL
                  WHERE id=? AND estado='aprobada'
                    AND programa_id=(SELECT programa_id FROM estudiantes WHERE usuario_id=?)
                    AND EXISTS (SELECT 1 FROM direcciones_ideas d WHERE d.idea_id=ideas.id)
                    AND (seleccionada_por IS NULL OR (seleccionada_hasta IS NOT NULL AND seleccionada_hasta<=NOW()))
                <sql:param value="${sessionScope.userId}" />
                <sql:param value="${param.ideaId}" />
                <sql:param value="${sessionScope.userId}" />
                </sql:update>
              </c:if>
              <c:if test="${reservedIdea eq 1}">
                <sql:query var="previousRequest">
                  SELECT id FROM solicitudes_ideas
                  WHERE idea_id=? AND estudiante_id=?
                  <sql:param value="${param.ideaId}" />
                  <sql:param value="${sessionScope.userId}" />
                </sql:query>
                <c:choose>
                  <c:when test="${not empty previousRequest.rows}">
                    <sql:update var="renewedRequest">
                      UPDATE solicitudes_ideas
                      SET comprobante_pago_url=?,mensaje=NULLIF(?,''),integrante_id=?,estado='pendiente',pago_verificado=0,
                          respuesta=NULL,respondida_por=NULL,respondida_en=NULL,corregir_hasta=NULL
                      WHERE id=? AND (estado='retirada' OR (estado='rechazada' AND corregir_hasta<=NOW()))
                      <sql:param value="${fn:trim(param.receiptUrl)}" />
                      <sql:param value="${fn:trim(param.message)}" />
                      <sql:param value="${empty param.partnerCode ? null : partnerId}" />
                      <sql:param value="${previousRequest.rows[0].id}" />
                    </sql:update>
                  </c:when>
                  <c:otherwise>
                    <sql:update var="createdRequest">
                      INSERT INTO solicitudes_ideas (idea_id,estudiante_id,integrante_id,mensaje,comprobante_pago_url,estado)
                      VALUES (?,?,?,NULLIF(?,''),?,'pendiente')
                      <sql:param value="${param.ideaId}" />
                      <sql:param value="${sessionScope.userId}" />
                      <sql:param value="${empty param.partnerCode ? null : partnerId}" />
                      <sql:param value="${fn:trim(param.message)}" />
                      <sql:param value="${fn:trim(param.receiptUrl)}" />
                    </sql:update>
                  </c:otherwise>
                </c:choose>
              </c:if>
            </sql:transaction>
          </c:catch>
        </c:otherwise>
      </c:choose>
      <c:choose>
        <c:when test="${not empty requestFailure}">
          <c:set var="flashError" value="No se pudo registrar la solicitud. Inténtalo nuevamente." scope="session" />
        </c:when>
        <c:when test="${param.action eq 'cancel' and canceledRequest ne 1}">
          <c:set var="flashError" value="No se pudo cancelar: la solicitud ya terminó o la idea ya no está vinculada a tu cuenta." scope="session" />
        </c:when>
        <c:when test="${param.action eq 'cancel'}">
          <c:set var="flashNotice" value="Cancelaste el proceso y la idea quedó libre para que otro estudiante pueda seleccionarla." scope="session" />
        </c:when>
        <c:when test="${param.action eq 'correct' and renewedRequest ne 1}">
          <c:set var="flashError" value="El plazo para corregir venció o la solicitud ya fue actualizada." scope="session" />
        </c:when>
        <c:when test="${param.action eq 'request' and anotherActiveProcess}">
          <c:set var="flashError" value="Tú o el estudiante que agregaste ya tiene una idea en proceso. No se puede registrar otra hasta que ese proceso termine." scope="session" />
        </c:when>
        <c:when test="${param.action eq 'request' and reservedIdea ne 1}">
          <c:set var="flashError" value="Esta idea ya fue solicitada, no está disponible o no pertenece a tu programa." scope="session" />
        </c:when>
        <c:when test="${param.action eq 'request' and not empty previousRequest.rows and renewedRequest ne 1}">
          <c:set var="flashError" value="La idea ya no está disponible para corregir la solicitud." scope="session" />
        </c:when>
        <c:when test="${param.action eq 'request' and empty previousRequest.rows and createdRequest ne 1}">
          <c:set var="flashError" value="No se pudo crear la solicitud. Verifica que la idea siga disponible." scope="session" />
        </c:when>
        <c:otherwise>
          <c:choose>
            <c:when test="${param.action eq 'correct'}"><c:set var="flashNotice" value="Comprobante reenviado. La idea continúa reservada mientras coordinación revisa la corrección." scope="session" /></c:when>
            <c:otherwise><c:set var="flashNotice" value="Solicitud enviada. La idea quedó reservada mientras coordinación revisa el comprobante." scope="session" /></c:otherwise>
          </c:choose>
        </c:otherwise>
      </c:choose>
    </c:otherwise>
  </c:choose>
  <c:redirect url="/solicitudes-ideas.jsp" />
</c:if>
<c:if test="${not empty sessionScope.flashNotice}"><c:set var="pageNotice" value="${sessionScope.flashNotice}" /><c:remove var="flashNotice" scope="session" /></c:if>
<c:if test="${not empty sessionScope.flashError}"><c:set var="pageError" value="${sessionScope.flashError}" /><c:remove var="flashError" scope="session" /></c:if>
<sql:query var="selectedIdea" dataSource="jdbc/ProjectsDB">
  SELECT v.id,v.codigo,v.titulo,v.problema,v.descripcion,v.recursos_tecnologias,v.programa,v.area,v.proponente,director.nombre_completo AS director
  FROM ideas_aprobadas v
  JOIN ideas i ON i.id=v.id
  JOIN direcciones_ideas d ON d.idea_id=i.id
  JOIN usuarios director ON director.id=d.director_id
  WHERE v.id=? AND v.programa_id=?
    AND (i.seleccionada_por IS NULL OR (i.seleccionada_hasta IS NOT NULL AND i.seleccionada_hasta<=NOW()))
    AND NOT EXISTS (
      SELECT 1 FROM proyectos_finales completed_pf
      JOIN anteproyectos completed_ap ON completed_ap.id=completed_pf.anteproyecto_id
      WHERE completed_ap.idea_id=i.id AND completed_pf.estado='aprobado'
    )
    AND NOT EXISTS (
      SELECT 1 FROM solicitudes_ideas active_request
      WHERE (active_request.estudiante_id=? OR active_request.integrante_id=?) AND (
        active_request.estado IN ('pendiente','aprobada')
        OR (active_request.estado='rechazada' AND active_request.corregir_hasta>NOW())
      )
    )
  <sql:param value="${param.ideaId}" />
  <sql:param value="${activeStudent.rows[0].programa_id}" />
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<sql:query var="myRequests" dataSource="jdbc/ProjectsDB">
  SELECT s.id,s.idea_id,s.estudiante_id AS lider_id,s.estado,s.comprobante_pago_url,s.mensaje,s.respuesta,s.creada_en,s.respondida_en,s.corregir_hasta,s.pago_verificado,
    (s.corregir_hasta>NOW()) AS correccion_abierta,
    i.codigo,i.titulo,i.seleccionada_hasta,i.estado AS idea_estado,i.tipo,i.proponente_id,
    ap.estado AS anteproyecto_estado,
    final_project.estado AS proyecto_final_estado,
    CASE
      WHEN s.estado<>'aprobada' OR s.pago_verificado=0 THEN 1
      WHEN final_project.estado='pendiente_director' THEN 5
      WHEN final_project.estado='rechazado' AND final_review.etapa='director' THEN 5
      WHEN final_project.estado='aplazado' THEN 4
      WHEN final_project.estado IN ('pendiente_evaluador','aprobado') THEN 6
      WHEN final_project.estado='rechazado' AND final_review.etapa='evaluador' THEN 6
      WHEN ap.estado='aplazado' AND latest_review.etapa='evaluador' THEN 1
      WHEN ap.estado='pendiente_revision' THEN 2
      WHEN ap.estado='pendiente_evaluador' THEN 3
      WHEN ap.estado='aprobado' THEN 4
      WHEN ap.estado='aplazado' THEN 2
      WHEN ap.estado='rechazado' THEN CASE WHEN latest_review.etapa='evaluador' THEN 3 ELSE 2 END
      ELSE 1
    END AS fase_actual,
    d.nombre_completo AS director,evaluator.nombre_completo AS evaluador,
    CASE WHEN s.integrante_id=? THEN leader.nombre_completo ELSE partner.nombre_completo END AS integrante
  FROM solicitudes_ideas s
  JOIN ideas i ON i.id=s.idea_id
  LEFT JOIN anteproyectos ap ON ap.idea_id=s.idea_id AND ap.estudiante_id=s.estudiante_id
  LEFT JOIN proyectos_finales final_project ON final_project.anteproyecto_id=ap.id
  LEFT JOIN revisiones_proyectos_finales final_review ON final_review.id=(
    SELECT MAX(review.id) FROM revisiones_proyectos_finales review WHERE review.proyecto_final_id=final_project.id
  )
  LEFT JOIN revisiones_anteproyectos latest_review ON latest_review.id=(
    SELECT MAX(review.id) FROM revisiones_anteproyectos review WHERE review.anteproyecto_id=ap.id
  )
  LEFT JOIN direcciones_ideas asignacion ON asignacion.idea_id=i.id
  LEFT JOIN usuarios d ON d.id=asignacion.director_id
  LEFT JOIN evaluadores_ideas ei ON ei.idea_id=i.id
  LEFT JOIN usuarios evaluator ON evaluator.id=ei.evaluador_id
  LEFT JOIN usuarios leader ON leader.id=s.estudiante_id
  LEFT JOIN usuarios partner ON partner.id=s.integrante_id
  WHERE (s.estudiante_id=? OR s.integrante_id=?) AND s.estado<>'retirada'
    AND (final_project.id IS NULL OR final_project.estado<>'aprobado')
  ORDER BY s.creada_en DESC,s.id DESC
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<c:url var="stylesUrl" value="/assets/css/styles.css?v=20261016k" />
<c:url var="homeUrl" value="/index.jsp" />
<c:url var="ideasUrl" value="/banco-ideas.jsp" />
<c:url var="myIdeasUrl" value="/mis-ideas.jsp" />
<c:url var="anteproyectoUrl" value="/anteproyecto.jsp" />
<c:url var="logoutUrl" value="/logout.jsp" />
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="theme-color" content="#f5f7f6">
  <title>Solicitudes de ideas | Proyectos de grado UTS</title>
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
        <a class="nav-link" href="${anteproyectoUrl}"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M5 3.5h9l5 5v12H5v-17Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M14 3.5v5h5M8 13h8m-8 3.5h8" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>Mis anteproyectos</a>
        <a class="nav-link active" href="${requestsUrl}" aria-current="page"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5" stroke="currentColor" stroke-width="1.7"/><path d="M8 5V3.5h8V5m-12.5 5h17m-13 4h4m-4 3h8" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round" stroke-linecap="round"/></svg>Mis solicitudes</a>
        <a class="nav-link" href="https://www.uts.edu.co/calendario-academico/" target="_blank" rel="noopener noreferrer"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5" stroke="currentColor" stroke-width="1.7"/><path d="M7.5 3.5v3m9-3v3m-13 3h17m-13 4h3m3 0h3m-9 3.5h3" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>Calendario académico <span aria-hidden="true">↗</span></a>
      </nav>
      <div class="sidebar-bottom"><div class="admin-security-card"><span aria-hidden="true">✓</span><strong>Reserva de idea</strong><p>Al enviar la solicitud, la idea deja de estar disponible para otros estudiantes.</p></div><div class="sidebar-version">PLATAFORMA DE PROYECTOS <span>v1.0</span></div></div>
    </aside>
    <label class="sidebar-overlay" for="sidebarToggle" aria-label="Cerrar menú"></label>
    <section class="main-area">
      <header class="topbar"><label class="mobile-menu" for="sidebarToggle" aria-label="Abrir menú"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg></label><div class="breadcrumb"><a href="${homeUrl}">Estudiante</a><span class="crumb-slash">/</span><strong>Mis solicitudes</strong></div><div class="topbar-actions"><span class="demo-badge"><i></i> PORTAL ESTUDIANTIL</span><span class="topbar-divider"></span><a class="profile-button" href="${logoutUrl}"><span class="avatar"><c:out value="${fn:toUpperCase(fn:substring(currentUserName,0,1))}" /></span><span class="profile-info"><strong><c:out value="${currentUserName}" /></strong><small>Estudiante · Cerrar sesión</small></span></a></div></header>
      <main class="proposal-page anteproject-page">
        <div class="proposal-heading"><div><a class="back-link" href="${ideasUrl}"><span aria-hidden="true">←</span> Volver al banco de ideas</a><p class="section-overline"><span></span> ELECCIÓN DE PROYECTO</p><h1>Solicitudes de ideas</h1><p class="proposal-intro">Elige una idea de tu programa, adjunta el comprobante de pago y, si quieres, agrega un compañero de tu mismo programa.</p></div></div>
        <c:if test="${not empty pageError}"><div class="admin-alert admin-alert-error" role="alert"><strong>No se completó la operación.</strong><span><c:out value="${pageError}" /></span></div></c:if>
        <c:if test="${not empty pageNotice}"><div class="admin-alert admin-alert-success" role="status"><strong>Solicitud registrada</strong><span><c:out value="${pageNotice}" /></span></div></c:if>
        <c:choose>
          <c:when test="${not empty activeStudentProcess.rows}">
            <div class="admin-alert" role="status"><strong>Ya tienes un proceso de idea activo.</strong><span>Estás gestionando <c:out value="${activeStudentProcess.rows[0].titulo}" />. No puedes seleccionar ni proponer otra idea hasta que termine la revisión. Consulta abajo las novedades de coordinación.</span></div>
          </c:when>
          <c:when test="${not empty param.ideaId and not empty selectedIdea.rows}">
            <article class="coordinator-idea-card request-selected-idea">
              <header class="coordinator-idea-heading"><div><span class="coordinator-idea-code"><c:out value="${selectedIdea.rows[0].codigo}" /> · <c:out value="${selectedIdea.rows[0].area}" /></span><h2><c:out value="${selectedIdea.rows[0].titulo}" /></h2></div><span class="my-idea-status my-idea-status-approved">Disponible</span></header>
              <div class="coordinator-idea-meta"><span><strong>Programa</strong><c:out value="${selectedIdea.rows[0].programa}" /></span><span><strong>Director</strong><c:out value="${selectedIdea.rows[0].director}" /></span><span><strong>Propuesta por</strong><c:out value="${selectedIdea.rows[0].proponente}" /></span></div>
              <section class="coordinator-idea-description"><h3>Descripción</h3><p><c:out value="${selectedIdea.rows[0].descripcion}" /></p></section>
              <section class="coordinator-idea-description"><h3>Problema que aborda</h3><p><c:out value="${selectedIdea.rows[0].problema}" /></p></section>
              <form class="request-idea-form" action="${requestsUrl}" method="post">
                <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="action" value="request"><input type="hidden" name="ideaId" value="<c:out value='${selectedIdea.rows[0].id}' />">
                <label class="admin-field request-field-wide"><span>Enlace al PDF del comprobante de pago <i>*</i></span><input name="receiptUrl" type="url" maxlength="500" placeholder="https://drive.google.com/..." required><small>Comparte el PDF desde Google Drive o Google Docs y habilita el acceso de lectura para coordinación.</small></label>
                <label class="admin-field request-field-wide"><span>Compañero de proyecto <small>(opcional)</small></span><input name="partnerCode" type="text" maxlength="40" value="<c:out value='${param.partnerCode}' />" placeholder="Código estudiantil del compañero"><small>Debe pertenecer a tu mismo programa y no tener otro proceso de idea activo.</small></label>
                <label class="admin-field request-field-wide"><span>Mensaje para coordinación <small>(opcional)</small></span><textarea name="message" maxlength="800" rows="3" placeholder="Escribe información adicional sobre tu solicitud"></textarea></label>
                <p class="request-reservation-note">Al enviar, esta idea se reservará para ti mientras coordinación revisa el pago. Si coordinación solicita correcciones, tendrás 3 días para enviar un nuevo comprobante; de lo contrario se liberará.</p>
                <div class="teacher-idea-submit"><button class="button button-primary" type="submit">Solicitar esta idea <span aria-hidden="true">→</span></button></div>
              </form>
            </article>
          </c:when>
          <c:when test="${not empty param.ideaId}">
            <div class="admin-empty-state"><strong>Esta idea ya no está disponible.</strong><span>Puede que otro estudiante la haya solicitado o que no pertenezca a tu programa.</span><a href="${ideasUrl}">Volver al banco de ideas</a></div>
          </c:when>
        </c:choose>
        <section class="teacher-ideas-history request-history" aria-labelledby="myRequestsTitle">
          <div class="coordinator-history-heading"><div><p class="section-overline"><span></span> SEGUIMIENTO</p><h2 id="myRequestsTitle">Mis solicitudes</h2><p>Consulta las respuestas de coordinación y corrige el comprobante cuando sea necesario.</p></div><span class="admin-list-count"><c:out value="${fn:length(myRequests.rows)}" /> solicitudes</span></div>
          <c:choose>
            <c:when test="${empty myRequests.rows}"><div class="admin-empty-state"><strong>Aún no tienes solicitudes.</strong><span>Explora el banco y elige una idea aprobada de tu programa.</span></div></c:when>
            <c:otherwise><div class="coordinator-list">
              <c:forEach var="request" items="${myRequests.rows}">
                <article class="coordinator-idea-card">
                  <header class="coordinator-idea-heading"><div><span class="coordinator-idea-code"><c:out value="${request.codigo}" /> · Director: <c:out value="${request.director}" /></span><h2><c:out value="${request.titulo}" /></h2></div>
                    <c:choose><c:when test="${request.estado eq 'retirada'}"><span class="my-idea-status my-idea-status-rejected">Cancelada · idea liberada</span></c:when><c:when test="${request.estado eq 'aprobada'}"><span class="my-idea-status my-idea-status-approved">Asignada</span></c:when><c:when test="${request.estado eq 'pendiente' and request.tipo eq 'estudiantil' and request.proponente_id eq sessionScope.userId and request.pago_verificado}"><span class="my-idea-status my-idea-status-approved">Pago verificado · idea en revisión</span></c:when><c:when test="${request.estado eq 'rechazada' and request.correccion_abierta}"><span class="my-idea-status my-idea-status-changes">Corregir comprobante</span></c:when><c:when test="${request.estado eq 'rechazada' and request.idea_estado eq 'rechazada'}"><span class="my-idea-status my-idea-status-rejected">Idea rechazada · proceso finalizado</span></c:when><c:when test="${request.estado eq 'rechazada'}"><span class="my-idea-status my-idea-status-rejected">Plazo vencido · idea liberada</span></c:when><c:otherwise><span class="my-idea-status my-idea-status-pending">Pendiente de revisión</span></c:otherwise></c:choose>
                  </header>
                  <div class="coordinator-idea-meta"><span><strong>Solicitada</strong><c:out value="${request.creada_en}" /></span><c:if test="${not empty request.integrante}"><span><strong>Compañero de proyecto</strong><c:out value="${request.integrante}" /></span></c:if><c:if test="${not empty request.corregir_hasta and request.estado eq 'rechazada'}"><span><strong>Fecha límite de corrección</strong><c:out value="${request.corregir_hasta}" /></span></c:if><c:if test="${not empty request.respondida_en}"><span><strong>Última respuesta</strong><c:out value="${request.respondida_en}" /></span></c:if></div>
                  <c:if test="${request.estado eq 'pendiente' or request.estado eq 'aprobada' or (request.estado eq 'rechazada' and request.correccion_abierta)}"><jsp:include page="/WEB-INF/project-phase-tracker.jsp"><jsp:param name="phase" value="${request.fase_actual}" /><jsp:param name="requestState" value="${request.estado}" /></jsp:include></c:if>
                  <c:if test="${not empty request.evaluador}"><div class="coordinator-idea-meta"><span><strong>Evaluador asignado</strong><c:out value="${request.evaluador}" /></span></div></c:if>
                  <a class="drive-link" href="<c:out value='${request.comprobante_pago_url}' />" target="_blank" rel="noopener noreferrer">Abrir comprobante de pago <span aria-hidden="true">↗</span></a>
                  <c:if test="${not empty request.mensaje}"><div class="my-idea-feedback"><strong>Tu mensaje</strong><p><c:out value="${request.mensaje}" /></p></div></c:if>
                  <c:if test="${not empty request.respuesta}"><div class="my-idea-feedback"><strong>Respuesta de coordinación</strong><p><c:out value="${request.respuesta}" /></p></div></c:if>
                  <c:if test="${request.lider_id eq sessionScope.userId and request.estado eq 'rechazada' and request.correccion_abierta}">
                    <form class="request-idea-form request-correction-form" action="${requestsUrl}" method="post">
                      <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="action" value="correct"><input type="hidden" name="requestId" value="<c:out value='${request.id}' />">
                      <label class="admin-field request-field-wide"><span>Nuevo enlace al PDF corregido <i>*</i></span><input name="receiptUrl" type="url" maxlength="500" placeholder="https://drive.google.com/..." required><small>Tienes hasta <c:out value="${request.corregir_hasta}" /> para reenviarlo.</small></label>
                      <label class="admin-field request-field-wide"><span>Mensaje <small>(opcional)</small></span><textarea name="message" maxlength="800" rows="2"></textarea></label>
                      <div class="teacher-idea-submit"><button class="button button-primary" type="submit">Reenviar comprobante <span aria-hidden="true">→</span></button></div>
                    </form>
                  </c:if>
                  <c:if test="${request.estado eq 'aprobada'}"><p class="request-reservation-note">La idea está asignada a tu solicitud. Ya puedes continuar con la entrega de tu anteproyecto.</p><a class="button button-primary request-next-step" href="${anteproyectoUrl}">Ir a mis anteproyectos <span aria-hidden="true">→</span></a></c:if>
                  <c:if test="${request.estado eq 'retirada'}"><p class="request-reservation-note">Este proceso fue cancelado. La idea quedó libre para que cualquier estudiante pueda seleccionarla.</p></c:if>
                  <c:if test="${request.lider_id eq sessionScope.userId and (request.estado eq 'pendiente' or request.estado eq 'aprobada' or (request.estado eq 'rechazada' and request.correccion_abierta))}">
                    <form class="request-idea-form request-correction-form" action="${requestsUrl}" method="post">
                      <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="action" value="cancel"><input type="hidden" name="requestId" value="<c:out value='${request.id}' />">
                      <label class="request-cancel-confirm"><input type="checkbox" name="confirmCancel" value="yes" required><span>Confirmo que quiero cancelar esta idea y liberarla para otros estudiantes.</span></label>
                      <div class="teacher-idea-submit"><button class="button coordinator-reject-button" type="submit">Cancelar idea</button></div>
                    </form>
                  </c:if>
                </article>
              </c:forEach>
            </div></c:otherwise>
          </c:choose>
        </section>
        <footer class="dashboard-footer"><span>Universitaria Tecnológica de Santander</span><span>Puedes cancelar el proceso en cualquier momento; si vence el plazo de corrección, la idea también se libera automáticamente.</span></footer>
      </main>
    </section>
  </div>
</body>
</html>

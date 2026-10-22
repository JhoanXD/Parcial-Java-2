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
      <c:when test="${activeUser.rows[0].rol eq 'docente'}"><c:redirect url="/docente.jsp?view=ideas" /></c:when>
      <c:when test="${activeUser.rows[0].rol ne 'estudiante'}"><c:redirect url="/login.jsp" /></c:when>
      <c:otherwise><c:set var="currentUserName" value="${activeUser.rows[0].nombre_completo}" /></c:otherwise>
    </c:choose>
  </c:otherwise>
</c:choose>
<sql:query var="studentProfile" dataSource="jdbc/ProjectsDB">
  SELECT e.programa_id,p.nombre AS programa
  FROM estudiantes e JOIN programas_academicos p ON p.id=e.programa_id
  WHERE e.usuario_id=? AND p.activo=1
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<sql:query var="partnerCandidate" dataSource="jdbc/ProjectsDB">
  SELECT e.usuario_id,e.programa_id,u.nombre_completo,e.codigo_estudiantil
  FROM estudiantes e
  JOIN usuarios u ON u.id=e.usuario_id AND u.estado='activo'
  JOIN usuario_roles ur ON ur.usuario_id=u.id
  JOIN roles r ON r.id=ur.rol_id AND r.nombre='estudiante'
  WHERE e.codigo_estudiantil=? AND e.usuario_id<>?
    AND e.programa_id=(SELECT programa_id FROM estudiantes WHERE usuario_id=?)
  <sql:param value="${fn:trim(param.partnerCode)}" />
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<c:set var="partnerId" value="${empty partnerCandidate.rows ? sessionScope.userId : partnerCandidate.rows[0].usuario_id}" />
<sql:query var="activeStudentProcess" dataSource="jdbc/ProjectsDB">
  SELECT s.id,s.estado,s.corregir_hasta,i.titulo,i.tipo
  FROM solicitudes_ideas s JOIN ideas i ON i.id=s.idea_id
  WHERE (s.estudiante_id=? OR s.integrante_id=?)
    AND (s.estado IN ('pendiente','aprobada') OR (s.estado='rechazada' AND s.corregir_hasta>NOW()))
  ORDER BY s.creada_en DESC,s.id DESC LIMIT 1
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<sql:query var="areaRows" dataSource="jdbc/ProjectsDB">SELECT id,nombre FROM areas_tematicas WHERE activa=1 ORDER BY nombre</sql:query>
<c:if test="${empty sessionScope.csrfToken}">
  <sql:query var="newCsrf" dataSource="jdbc/ProjectsDB">SELECT LOWER(SHA2(CONCAT(UUID(), RAND(), UUID(), NOW(6)), 256)) AS token</sql:query>
  <c:set var="csrfToken" value="${newCsrf.rows[0].token}" scope="session" />
</c:if>
<c:if test="${pageContext.request.method eq 'POST'}">
  <c:choose>
    <c:when test="${empty sessionScope.csrfToken or empty param.csrfToken or sessionScope.csrfToken ne param.csrfToken}">
      <c:set var="proposalError" value="El formulario expiró. Recarga la página e inténtalo de nuevo." />
    </c:when>
    <c:when test="${empty studentProfile.rows}">
      <c:set var="proposalError" value="Tu cuenta no tiene un programa académico activo asociado. Contacta a la coordinación." />
    </c:when>
    <c:when test="${not empty fn:trim(param.partnerCode) and empty partnerCandidate.rows}">
      <c:set var="proposalError" value="El código del compañero no corresponde a un estudiante activo de tu mismo programa." />
    </c:when>
    <c:when test="${empty fn:trim(param.title) or fn:length(param.title) gt 120 or empty fn:trim(param.problem) or fn:length(param.problem) gt 1200 or empty fn:trim(param.description) or fn:length(param.description) gt 1800 or fn:length(param.resources) gt 800 or empty param.areaId or empty fn:trim(param.receiptUrl) or fn:length(fn:trim(param.receiptUrl)) gt 500 or (not fn:startsWith(fn:toLowerCase(fn:trim(param.receiptUrl)),'https://drive.google.com/') and not fn:startsWith(fn:toLowerCase(fn:trim(param.receiptUrl)),'https://docs.google.com/'))}">
      <c:set var="proposalError" value="Completa los campos obligatorios y verifica los límites de caracteres." />
    </c:when>
    <c:otherwise>
      <sql:query var="selectedArea" dataSource="jdbc/ProjectsDB">
        SELECT id FROM areas_tematicas WHERE id=? AND activa=1
        <sql:param value="${param.areaId}" />
      </sql:query>
      <c:choose>
        <c:when test="${empty selectedArea.rows}">
          <c:set var="proposalError" value="Selecciona un área temática válida." />
        </c:when>
        <c:otherwise>
          <c:set var="createdIdea" value="0" />
          <c:set var="createdRequest" value="0" />
          <c:catch var="proposalDatabaseFailure">
            <sql:transaction dataSource="jdbc/ProjectsDB">
              <sql:query var="studentLock">
                SELECT usuario_id FROM estudiantes WHERE usuario_id=? OR usuario_id=? ORDER BY usuario_id FOR UPDATE
                <sql:param value="${sessionScope.userId}" />
                <sql:param value="${partnerId}" />
              </sql:query>
              <sql:query var="activeProcess">
                SELECT id FROM solicitudes_ideas
                WHERE (estudiante_id=? OR integrante_id=? OR estudiante_id=? OR integrante_id=?)
                  AND (estado IN ('pendiente','aprobada') OR (estado='rechazada' AND corregir_hasta>NOW()))
                LIMIT 1
                <sql:param value="${sessionScope.userId}" />
                <sql:param value="${sessionScope.userId}" />
                <sql:param value="${partnerId}" />
                <sql:param value="${partnerId}" />
              </sql:query>
              <c:if test="${empty activeProcess.rows and not empty studentLock.rows}">
                <sql:update>
                  UPDATE ideas SET seleccionada_por=NULL,seleccionada_hasta=NULL
                  WHERE seleccionada_por=? AND seleccionada_hasta IS NOT NULL AND seleccionada_hasta<=NOW()
                  <sql:param value="${sessionScope.userId}" />
                </sql:update>
              </c:if>
              <c:if test="${empty activeProcess.rows and not empty studentLock.rows}">
                <sql:update var="createdIdea">
                  INSERT INTO ideas (codigo,titulo,problema,descripcion,recursos_tecnologias,tipo,estado,programa_id,area_id,proponente_id,seleccionada_por,enviada_en)
                  SELECT CONCAT('IDEA-',UPPER(SUBSTRING(REPLACE(UUID(),'-',''),1,16))),?,?,?,NULLIF(?,''),'estudiantil','pendiente_revision',e.programa_id,?,?,?,NOW()
                  FROM estudiantes e
                  WHERE e.usuario_id=? AND e.programa_id=? AND EXISTS (
                    SELECT 1 FROM areas_tematicas a WHERE a.id=? AND a.activa=1
                  )
                  <sql:param value="${fn:trim(param.title)}" />
                  <sql:param value="${fn:trim(param.problem)}" />
                  <sql:param value="${fn:trim(param.description)}" />
                  <sql:param value="${fn:trim(param.resources)}" />
                  <sql:param value="${param.areaId}" />
                  <sql:param value="${sessionScope.userId}" />
                  <sql:param value="${sessionScope.userId}" />
                  <sql:param value="${sessionScope.userId}" />
                  <sql:param value="${studentProfile.rows[0].programa_id}" />
                  <sql:param value="${param.areaId}" />
                </sql:update>
                <c:if test="${createdIdea eq 1}">
                  <sql:query var="createdIdeaId">
                    SELECT LAST_INSERT_ID() AS id
                  </sql:query>
                  <sql:update var="createdRequest">
                    INSERT INTO solicitudes_ideas (idea_id,estudiante_id,integrante_id,mensaje,comprobante_pago_url,estado)
                    VALUES (?,?,NULLIF(?,''),NULL,?,'pendiente')
                    <sql:param value="${createdIdeaId.rows[0].id}" />
                    <sql:param value="${sessionScope.userId}" />
                    <sql:param value="${empty param.partnerCode ? '' : partnerId}" />
                    <sql:param value="${fn:trim(param.receiptUrl)}" />
                  </sql:update>
                </c:if>
              </c:if>
            </sql:transaction>
          </c:catch>
          <c:choose>
            <c:when test="${not empty proposalDatabaseFailure}">
              <c:set var="proposalError" value="No se pudo enviar la propuesta. Inténtalo nuevamente." />
            </c:when>
            <c:when test="${not empty activeProcess.rows}">
              <c:set var="proposalError" value="Tú o el estudiante que agregaste ya tiene una idea en proceso. No se puede registrar otra hasta que ese proceso termine." />
            </c:when>
            <c:when test="${createdIdea ne 1}">
              <c:set var="proposalError" value="No se pudo asociar la propuesta a tu cuenta y programa. Contacta a la coordinación." />
            </c:when>
            <c:when test="${createdRequest ne 1}">
              <c:set var="proposalError" value="No se pudo registrar el comprobante de pago; la propuesta no fue guardada. Inténtalo nuevamente." />
            </c:when>
            <c:otherwise>
              <c:set var="proposalNotice" value="Tu idea y el comprobante de pago se enviaron a coordinación. No podrás solicitar ni proponer otra idea mientras se revisa." scope="session" />
              <c:redirect url="/crear-idea.jsp" />
            </c:otherwise>
          </c:choose>
        </c:otherwise>
      </c:choose>
    </c:otherwise>
  </c:choose>
</c:if>
<c:url var="stylesUrl" value="/assets/css/styles.css" />
<c:url var="homeUrl" value="/index.jsp" />
<c:url var="ideasUrl" value="/banco-ideas.jsp" />
<c:url var="myIdeasUrl" value="/mis-ideas.jsp" />
<c:url var="proposalUrl" value="/crear-idea.jsp" />
<c:url var="anteproyectoUrl" value="/anteproyecto.jsp" />
<c:url var="requestsUrl" value="/solicitudes-ideas.jsp" />
<c:url var="loginUrl" value="/logout.jsp" />
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#f5f7f6">
  <title>Proponer una idea | Proyectos de grado UTS</title>
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
        <a class="nav-link" href="${homeUrl}">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="m3.5 10 8.5-7 8.5 7v9a1.5 1.5 0 0 1-1.5 1.5h-14A1.5 1.5 0 0 1 3.5 19v-9Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M9 20.5v-7h6v7" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/></svg>
          Inicio
        </a>
        <a class="nav-link" href="${ideasUrl}">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M9 18h6m-5 3h4m-2-19a7 7 0 0 0-4.2 12.6c.8.6 1.2 1.3 1.2 2.4h6c0-1.1.4-1.8 1.2-2.4A7 7 0 0 0 12 2Z" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>
          Banco de ideas
        </a>
        <a class="nav-link active" href="${proposalUrl}" aria-current="page">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 5v14m-7-7h14" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.7"/></svg>
          Proponer una idea
        </a>
        <a class="nav-link" href="${myIdeasUrl}">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5" stroke="currentColor" stroke-width="1.7"/><path d="M8 5V3.5h8V5m-12.5 5h17" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/></svg>
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
        <div class="breadcrumb"><a href="${homeUrl}">Estudiante</a><span class="crumb-slash">/</span><strong>Proponer una idea</strong></div>
        <div class="topbar-actions">
          <span class="demo-badge"><i></i> PORTAL ESTUDIANTIL</span>
          <span class="topbar-divider"></span>
          <a class="profile-button" href="${loginUrl}" aria-label="Cerrar sesión" title="Cerrar sesión">
            <span class="avatar"><c:out value="${fn:toUpperCase(fn:substring(currentUserName, 0, 1))}" /></span><span class="profile-info"><strong><c:out value="${currentUserName}" /></strong><small>Estudiante · Cerrar sesión</small></span>
          </a>
        </div>
      </header>

      <main class="proposal-page">
        <div class="proposal-heading">
          <div>
            <a class="back-link" href="${ideasUrl}"><span aria-hidden="true">←</span> Volver a ideas aprobadas</a>
            <p class="section-overline"><span></span> TU IDEA TAMBIÉN PUEDE HACER LA DIFERENCIA</p>
            <h1>Propón una idea de proyecto</h1>
            <p class="proposal-intro">Cuéntanos qué te gustaría investigar o desarrollar. Puedes agregar un compañero de tu mismo programa. La coordinación revisará la propuesta antes de que pueda ser consultada por otros estudiantes.</p>
          </div>
          <span class="proposal-step"><span>01</span> NUEVA PROPUESTA</span>
        </div>

        <c:if test="${not empty proposalNotice}"><div class="proposal-message proposal-message-success" role="status"><strong><c:out value="${proposalNotice}" /></strong><span>Podrás consultar la respuesta una vez que coordinación revise la propuesta.</span></div><c:remove var="proposalNotice" scope="session" /></c:if>
        <c:if test="${not empty proposalError}"><div class="proposal-message" role="alert"><strong>No se pudo enviar la propuesta.</strong><span><c:out value="${proposalError}" /></span></div></c:if>
        <c:if test="${empty studentProfile.rows}"><div class="proposal-message" role="alert"><strong>Falta configurar tu perfil académico.</strong><span>Solicita al administrador que asocie tu cuenta a un programa académico.</span></div></c:if>

        <c:choose>
          <c:when test="${not empty activeStudentProcess.rows}">
            <div class="admin-alert" role="status"><strong>Ya tienes un proceso de idea activo.</strong><span>Completa la revisión de <c:out value="${activeStudentProcess.rows[0].titulo}" /> antes de solicitar o proponer otra idea. Consulta el estado en <a href="${myIdeasUrl}">Mis ideas</a> o en <a href="${requestsUrl}">Mis solicitudes</a>.</span></div>
          </c:when>
          <c:otherwise>
        <div class="proposal-layout">
          <form class="proposal-form" action="${proposalUrl}" method="post">
            <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />">
            <section class="form-section" aria-labelledby="basicInfoTitle">
              <div class="form-section-heading">
                <span class="form-section-number">1</span>
                <div><h2 id="basicInfoTitle">Información general</h2><p>Identifica tu propuesta y el área académica relacionada.</p></div>
              </div>
              <div class="form-fields">
                <label class="form-field form-field-wide" for="ideaTitle">
                  <span>Título de la idea <i>*</i></span>
                  <input id="ideaTitle" name="title" type="text" maxlength="120" placeholder="Ej. Aplicación para optimizar el consumo de agua" value="${fn:escapeXml(param.title)}" required>
                  <small>Escribe un título claro y concreto (máximo 120 caracteres).</small>
                </label>
                <label class="form-field" for="academicProgram">
                  <span>Programa académico</span>
                  <input id="academicProgram" type="text" value="<c:out value='${studentProfile.rows[0].programa}' />" readonly>
                </label>
                <label class="form-field" for="area">
                  <span>Área temática <i>*</i></span>
                  <select id="area" name="areaId" required>
                    <option value="">Selecciona un área</option>
                    <c:forEach var="areaRow" items="${areaRows.rows}"><option value="<c:out value='${areaRow.id}' />" ${param.areaId eq areaRow.id ? 'selected' : ''}><c:out value="${areaRow.nombre}" /></option></c:forEach>
                  </select>
                </label>
                <label class="form-field form-field-wide" for="partnerCode">
                  <span>Compañero de proyecto <small>(opcional)</small></span>
                  <input id="partnerCode" name="partnerCode" type="text" maxlength="40" value="${fn:escapeXml(param.partnerCode)}" placeholder="Código estudiantil del compañero">
                  <small>Debe pertenecer a tu mismo programa y no tener otro proceso de idea activo.</small>
                </label>
              </div>
            </section>

            <section class="form-section" aria-labelledby="ideaDetailTitle">
              <div class="form-section-heading">
                <span class="form-section-number">2</span>
                <div><h2 id="ideaDetailTitle">Cuéntanos sobre tu idea</h2><p>Describe la situación que quieres mejorar y cómo imaginas tu propuesta.</p></div>
              </div>
              <div class="form-fields">
                <label class="form-field form-field-wide" for="problem">
                  <span>Problema o necesidad identificada <i>*</i></span>
                  <textarea id="problem" name="problem" rows="4" maxlength="1200" placeholder="¿Qué situación, necesidad o problema te gustaría abordar?" required><c:out value="${param.problem}" /></textarea>
                  <small>Explica a quién afecta y por qué es importante atenderlo.</small>
                </label>
                <label class="form-field form-field-wide" for="description">
                  <span>Descripción de la propuesta <i>*</i></span>
                  <textarea id="description" name="description" rows="5" maxlength="1800" placeholder="¿Qué propones hacer? Incluye el objetivo y el resultado que esperas alcanzar." required><c:out value="${param.description}" /></textarea>
                  <small>Resume el objetivo, el enfoque y el resultado esperado.</small>
                </label>
                <label class="form-field form-field-wide" for="resources">
                  <span>Tecnologías o recursos que podrían utilizarse <small>(opcional)</small></span>
                  <textarea id="resources" name="resources" rows="3" maxlength="800" placeholder="Herramientas, tecnologías, datos o recursos que tienes en mente"><c:out value="${param.resources}" /></textarea>
                </label>
                <label class="form-field form-field-wide" for="receiptUrl">
                  <span>Enlace al PDF del comprobante de pago <i>*</i></span>
                  <input id="receiptUrl" name="receiptUrl" type="url" maxlength="500" value="${fn:escapeXml(param.receiptUrl)}" placeholder="https://drive.google.com/..." required>
                  <small>Comparte el PDF desde Google Drive o Google Docs y habilita el acceso de lectura para coordinación.</small>
                </label>
              </div>
            </section>

            <div class="proposal-consent">
              <span class="consent-mark" aria-hidden="true">✓</span>
              <p>Confirmo que la idea descrita es de mi autoría o que cuento con autorización para presentarla, y entiendo que será revisada antes de su aprobación.</p>
            </div>
            <div class="proposal-actions">
              <a class="button button-secondary" href="${homeUrl}">Cancelar</a>
              <button class="button button-primary" type="submit">Enviar para revisión <span aria-hidden="true">→</span></button>
            </div>
          </form>

          <aside class="proposal-aside" aria-label="Información sobre el proceso de revisión">
            <div class="review-card">
              <span class="review-icon" aria-hidden="true">✳</span>
              <p class="review-eyebrow">¿QUÉ SIGUE?</p>
              <h2>Tu idea será revisada</h2>
              <p>Coordinación revisará el comprobante de pago y la propuesta antes de asignarla.</p>
              <ol class="review-steps">
                <li><span>1</span><div><strong>Presentas idea y comprobante</strong><small>Incluye el enlace al PDF del pago.</small></div></li>
                <li><span>2</span><div><strong>Coordinación revisa</strong><small>Verifica el pago y la pertinencia académica.</small></div></li>
                <li><span>3</span><div><strong>Se asigna al aprobarse</strong><small>Mientras tanto no podrás solicitar otra idea.</small></div></li>
              </ol>
            </div>
            <div class="proposal-tip">
              <strong>Una buena propuesta</strong>
              <p>Explica con claridad el problema, a quién beneficia y qué resultado concreto esperas lograr.</p>
            </div>
          </aside>
        </div>
          </c:otherwise>
        </c:choose>
        <footer class="dashboard-footer"><span>Universitaria Tecnológica de Santander</span><span>Las propuestas enviadas quedan pendientes de revisión académica.</span></footer>
      </main>
    </section>
  </div>
</body>
</html>

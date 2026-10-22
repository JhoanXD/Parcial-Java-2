<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<c:if test="${pageContext.request.method ne 'POST' and empty sessionScope.csrfToken}">
  <sql:query var="newCsrf" dataSource="jdbc/ProjectsDB">SELECT LOWER(SHA2(CONCAT(UUID(), RAND(), UUID(), NOW(6)), 256)) AS token</sql:query>
  <c:set var="csrfToken" value="${newCsrf.rows[0].token}" scope="session" />
</c:if>
<c:if test="${not empty sessionScope.userId}">
  <sql:query var="existingSession" dataSource="jdbc/ProjectsDB">
    SELECT u.id, u.nombre_completo, r.nombre AS rol
    FROM usuarios u
    JOIN usuario_roles ur ON ur.usuario_id=u.id
    JOIN roles r ON r.id=ur.rol_id
    WHERE u.id=? AND u.estado='activo'
    ORDER BY CASE r.nombre WHEN 'administrador' THEN 1 WHEN 'coordinador' THEN 2 WHEN 'docente' THEN 3 WHEN 'estudiante' THEN 4 ELSE 5 END
    LIMIT 1
    <sql:param value="${sessionScope.userId}" />
  </sql:query>
  <c:choose>
    <c:when test="${not empty existingSession.rows and existingSession.rows[0].rol eq 'administrador'}"><c:redirect url="/admin-usuarios.jsp" /></c:when>
    <c:when test="${not empty existingSession.rows and existingSession.rows[0].rol eq 'coordinador'}"><c:redirect url="/coordinador-ideas.jsp" /></c:when>
    <c:when test="${not empty existingSession.rows and existingSession.rows[0].rol eq 'docente'}"><c:redirect url="/docente.jsp" /></c:when>
    <c:when test="${not empty existingSession.rows and existingSession.rows[0].rol eq 'estudiante'}"><c:redirect url="/index.jsp" /></c:when>
    <c:otherwise>
      <c:remove var="userId" scope="session" />
      <c:remove var="userName" scope="session" />
      <c:remove var="userRole" scope="session" />
    </c:otherwise>
  </c:choose>
</c:if>
<c:if test="${pageContext.request.method eq 'POST'}">
  <c:choose>
    <c:when test="${empty sessionScope.csrfToken or empty param.csrfToken or sessionScope.csrfToken ne param.csrfToken}">
      <c:set var="loginError" value="La solicitud de acceso expiró. Recarga la página e inténtalo de nuevo." />
    </c:when>
    <c:otherwise>
      <sql:query var="loginResult" dataSource="jdbc/ProjectsDB">
        SELECT u.id, u.nombre_completo, r.nombre AS rol
        FROM usuarios u
        JOIN usuario_roles ur ON ur.usuario_id=u.id
        JOIN roles r ON r.id=ur.rol_id
        WHERE LOWER(u.correo)=LOWER(?) AND u.estado='activo'
          AND u.salt_contrasena IS NOT NULL
          AND u.hash_contrasena=pg_password_digest(?, u.salt_contrasena)
        ORDER BY CASE r.nombre WHEN 'administrador' THEN 1 WHEN 'coordinador' THEN 2 WHEN 'docente' THEN 3 WHEN 'estudiante' THEN 4 ELSE 5 END
        LIMIT 1
        <sql:param value="${param.email}" />
        <sql:param value="${param.password}" />
      </sql:query>
      <c:choose>
        <c:when test="${not empty loginResult.rows and loginResult.rows[0].rol eq 'administrador'}">
          <c:set var="userId" value="${loginResult.rows[0].id}" scope="session" />
          <c:set var="userName" value="${loginResult.rows[0].nombre_completo}" scope="session" />
          <c:set var="userRole" value="${loginResult.rows[0].rol}" scope="session" />
          <sql:query var="newCsrf" dataSource="jdbc/ProjectsDB">SELECT LOWER(SHA2(CONCAT(UUID(), RAND(), UUID(), NOW(6)), 256)) AS token</sql:query>
          <c:set var="csrfToken" value="${newCsrf.rows[0].token}" scope="session" />
          <c:choose>
            <c:when test="${param.returnTo eq 'users'}"><c:redirect url="/usuarios-publicos.jsp" /></c:when>
            <c:otherwise><c:redirect url="/admin-usuarios.jsp" /></c:otherwise>
          </c:choose>
        </c:when>
        <c:when test="${not empty loginResult.rows and loginResult.rows[0].rol eq 'coordinador'}">
          <c:set var="userId" value="${loginResult.rows[0].id}" scope="session" />
          <c:set var="userName" value="${loginResult.rows[0].nombre_completo}" scope="session" />
          <c:set var="userRole" value="${loginResult.rows[0].rol}" scope="session" />
          <sql:query var="newCsrf" dataSource="jdbc/ProjectsDB">SELECT LOWER(SHA2(CONCAT(UUID(), RAND(), UUID(), NOW(6)), 256)) AS token</sql:query>
          <c:set var="csrfToken" value="${newCsrf.rows[0].token}" scope="session" />
          <c:redirect url="/coordinador-ideas.jsp" />
        </c:when>
        <c:when test="${not empty loginResult.rows and loginResult.rows[0].rol eq 'docente'}">
          <c:set var="userId" value="${loginResult.rows[0].id}" scope="session" />
          <c:set var="userName" value="${loginResult.rows[0].nombre_completo}" scope="session" />
          <c:set var="userRole" value="${loginResult.rows[0].rol}" scope="session" />
          <sql:query var="newCsrf" dataSource="jdbc/ProjectsDB">SELECT LOWER(SHA2(CONCAT(UUID(), RAND(), UUID(), NOW(6)), 256)) AS token</sql:query>
          <c:set var="csrfToken" value="${newCsrf.rows[0].token}" scope="session" />
          <c:redirect url="/docente.jsp" />
        </c:when>
        <c:when test="${not empty loginResult.rows and loginResult.rows[0].rol eq 'estudiante'}">
          <c:set var="userId" value="${loginResult.rows[0].id}" scope="session" />
          <c:set var="userName" value="${loginResult.rows[0].nombre_completo}" scope="session" />
          <c:set var="userRole" value="${loginResult.rows[0].rol}" scope="session" />
          <sql:query var="newCsrf" dataSource="jdbc/ProjectsDB">SELECT LOWER(SHA2(CONCAT(UUID(), RAND(), UUID(), NOW(6)), 256)) AS token</sql:query>
          <c:set var="csrfToken" value="${newCsrf.rows[0].token}" scope="session" />
          <c:redirect url="/index.jsp" />
        </c:when>
        <c:otherwise>
          <c:choose>
            <c:when test="${empty loginResult.rows}"><c:set var="loginError" value="Correo o contraseña incorrectos, o cuenta no habilitada." /></c:when>
            <c:otherwise><c:set var="loginError" value="Correo o contraseña incorrectos, o rol no habilitado." /></c:otherwise>
          </c:choose>
        </c:otherwise>
      </c:choose>
    </c:otherwise>
  </c:choose>
</c:if>
<c:url var="stylesUrl" value="/assets/css/styles.css?v=20261016n" />
<c:url var="homeUrl" value="/index.jsp" />
<c:url var="loginUrl" value="/login.jsp" />
<c:url var="publicUsersUrl" value="/usuarios-publicos.jsp" />
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#f5f7f6">
  <title>Iniciar sesión | Proyectos de grado UTS</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="${stylesUrl}">
</head>
<body>
  <main class="login-view">
    <section class="login-panel" aria-labelledby="loginTitle">
      <a class="brand brand-login" href="${homeUrl}" aria-label="UTS Proyectos de grado">
        <span class="brand-mark" aria-hidden="true"><span>U</span><span>T</span><span>S</span></span>
        <span class="brand-copy"><strong>UTS</strong><span>Proyectos de grado</span></span>
      </a>

      <div class="login-content">
        <span class="eyebrow">PLATAFORMA ACADÉMICA</span>
        <h1 id="loginTitle">Tu próximo gran proyecto <span>comienza aquí.</span></h1>
        <p class="login-intro">Ingresa para descubrir ideas aprobadas y dar el primer paso hacia tu proyecto de grado.</p>

        <form class="login-form" action="${loginUrl}" method="post">
          <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />">
          <c:if test="${param.returnTo eq 'users'}"><input type="hidden" name="returnTo" value="users"></c:if>
          <label for="email">Correo institucional</label>
          <div class="input-wrap">
            <svg class="field-icon" viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3.5" y="5.5" width="17" height="13" rx="2.5" stroke="currentColor" stroke-width="1.7"/><path d="m5 7 7 5.5L19 7" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>
            <input id="email" name="email" type="email" placeholder="nombre@correo.edu.co" autocomplete="username" value="<c:out value='${param.email}' />" required>
          </div>

          <div class="label-row">
            <label for="password">Contraseña</label>
            <span class="text-link">¿Olvidaste tu contraseña?</span>
          </div>
          <div class="input-wrap">
            <svg class="field-icon" viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="4.5" y="10" width="15" height="10" rx="2.5" stroke="currentColor" stroke-width="1.7"/><path d="M8 10V7a4 4 0 1 1 8 0v3m-4 4v2" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>
            <input id="password" name="password" type="password" placeholder="Ingresa tu contraseña" autocomplete="current-password" required>
          </div>

          <button class="button button-primary login-submit" type="submit">Continuar al inicio <span aria-hidden="true">→</span></button>
          <p class="login-hint">¿Aún no tienes cuenta? Contacta al administrador</p>
        </form>
        <a class="button login-directory-link" href="${publicUsersUrl}">Consultar directorio de usuarios</a>
        <c:if test="${not empty loginError}">
          <p class="login-error" role="alert"><c:out value="${loginError}" /></p>
        </c:if>
        <p class="prototype-note"><span aria-hidden="true"></span> Acceso institucional</p>
      </div>

      <footer class="login-footer">
        <span>Universitaria Tecnológica de Santander</span>
        <span>© 2026 UTS</span>
      </footer>
    </section>

    <aside class="login-art" aria-label="Información de la plataforma">
      <div class="art-orbit orbit-one"></div>
      <div class="art-orbit orbit-two"></div>
      <div class="art-grid"></div>
      <div class="art-topline"><span class="status-dot"></span> TU CAMINO, UNA IDEA A LA VEZ</div>
      <div class="art-content">
        <div class="art-illustration" aria-hidden="true">
          <div class="illustration-card card-back"><span class="mini-line"></span><span class="mini-line short"></span><span class="mini-chip"></span></div>
          <div class="illustration-card card-front">
            <div class="bulb"><svg viewBox="0 0 40 40" fill="none"><path d="M13 17a7 7 0 1 1 14 0c0 2.5-1.3 4-2.7 5.5-.9 1-1.3 1.8-1.3 3.5h-6c0-1.7-.4-2.5-1.3-3.5C14.3 21 13 19.5 13 17Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M17 30h6m-5 3h4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg></div>
            <span class="idea-label">IDEA DESTACADA</span><strong>Innovar también es<br>hacer una buena pregunta.</strong>
            <span class="card-progress"><i></i></span>
          </div>
          <span class="float-star star-one">✳</span><span class="float-star star-two">✦</span>
          <span class="float-pill">IDEA <b>↗</b></span>
        </div>
        <p class="art-kicker">Imagina. Investiga. Transforma.</p>
        <h2>Las buenas ideas<br>merecen <em>hacerse realidad.</em></h2>
        <p class="art-description">Encuentra inspiración, conecta con docentes y construye un proyecto que deje huella.</p>
        <div class="art-pagination" aria-hidden="true"><span class="active"></span><span></span><span></span></div>
      </div>
      <div class="art-footer"><span>UN ESPACIO PARA TUS IDEAS</span><span>01 — 03</span></div>
    </aside>
  </main>
</body>
</html>

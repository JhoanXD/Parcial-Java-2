<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<c:choose>
  <c:when test="${empty sessionScope.userId}"><c:redirect url="/login.jsp" /></c:when>
  <c:otherwise>
    <sql:query var="activeAdmin" dataSource="jdbc/ProjectsDB">
      SELECT u.id,r.nombre AS rol
      FROM usuarios u
      JOIN usuario_roles ur ON ur.usuario_id=u.id
      JOIN roles r ON r.id=ur.rol_id
      WHERE u.id=? AND u.estado='activo'
      ORDER BY CASE r.nombre WHEN 'administrador' THEN 1 ELSE 2 END
      LIMIT 1
      <sql:param value="${sessionScope.userId}" />
    </sql:query>
    <c:choose>
      <c:when test="${empty activeAdmin.rows}">
        <c:remove var="userId" scope="session" />
        <c:remove var="userName" scope="session" />
        <c:remove var="userRole" scope="session" />
        <c:redirect url="/login.jsp" />
      </c:when>
      <c:when test="${activeAdmin.rows[0].rol ne 'administrador'}"><c:redirect url="/login.jsp" /></c:when>
      <c:otherwise><c:set var="isAdmin" value="true" /></c:otherwise>
    </c:choose>
  </c:otherwise>
</c:choose>
<c:if test="${isAdmin}">
<sql:query var="publicRoles" dataSource="jdbc/ProjectsDB">
  SELECT DISTINCT r.id,r.nombre
  FROM roles r
  JOIN usuario_roles ur ON ur.rol_id=r.id
  JOIN usuarios u ON u.id=ur.usuario_id
  ORDER BY CASE r.nombre
    WHEN 'administrador' THEN 1
    WHEN 'coordinador' THEN 2
    WHEN 'docente' THEN 3
    WHEN 'estudiante' THEN 4
    ELSE 5
  END,r.nombre
</sql:query>
<c:url var="stylesUrl" value="/assets/css/styles.css?v=20261016n" />
<c:url var="adminUrl" value="/admin-usuarios.jsp" />
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#f5f7f6">
  <title>Directorio de usuarios | Proyectos de grado UTS</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="${stylesUrl}">
</head>
<body>
  <main class="public-directory">
    <a class="brand" href="${adminUrl}" aria-label="Volver a gestión de usuarios">
      <span class="brand-mark" aria-hidden="true"><span>U</span><span>T</span><span>S</span></span>
      <span class="brand-copy"><strong>UTS</strong><span>Proyectos de grado</span></span>
    </a>
    <header class="public-directory-heading">
      <p class="section-overline"><span></span> PLATAFORMA ACADÉMICA</p>
      <h1>Directorio de usuarios</h1>
      <p>Información agrupada por rol, disponible únicamente para administradores. No se muestran contraseñas.</p>
    </header>
    <c:choose>
      <c:when test="${empty publicRoles.rows}">
        <div class="admin-empty-state"><strong>No hay usuarios para mostrar.</strong></div>
      </c:when>
      <c:otherwise>
        <div class="public-directory-groups">
          <c:forEach var="role" items="${publicRoles.rows}">
            <sql:query var="publicRoleUsers" dataSource="jdbc/ProjectsDB">
              SELECT u.id,u.nombre_completo,u.correo,e.codigo_estudiantil
              FROM usuarios u
              JOIN usuario_roles ur ON ur.usuario_id=u.id
              LEFT JOIN estudiantes e ON e.usuario_id=u.id
              WHERE ur.rol_id=?
              ORDER BY u.nombre_completo,u.id
              <sql:param value="${role.id}" />
            </sql:query>
            <section class="public-directory-group" aria-labelledby="role-${role.id}">
              <h2 id="role-${role.id}"><c:out value="${role.nombre}" /></h2>
              <div class="public-directory-list">
                <c:forEach var="user" items="${publicRoleUsers.rows}">
                  <article class="public-directory-card">
                    <div><span class="public-directory-label">Nombre</span><strong><c:out value="${user.nombre_completo}" /></strong></div>
                    <div><span class="public-directory-label">Correo</span><span><c:out value="${user.correo}" /></span></div>
                    <c:if test="${role.nombre eq 'estudiante' and not empty user.codigo_estudiantil}">
                      <div><span class="public-directory-label">Código estudiantil</span><span><c:out value="${user.codigo_estudiantil}" /></span></div>
                    </c:if>
                  </article>
                </c:forEach>
              </div>
            </section>
          </c:forEach>
        </div>
      </c:otherwise>
    </c:choose>
    <a class="button button-primary public-directory-back" href="${adminUrl}">Volver a gestión de usuarios</a>
  </main>
</body>
</html>
</c:if>

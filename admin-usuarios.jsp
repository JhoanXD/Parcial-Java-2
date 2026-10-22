<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<c:url var="stylesUrl" value="/assets/css/styles.css" />
<c:url var="adminUrl" value="/admin-usuarios.jsp" />
<c:url var="publicUsersUrl" value="/usuarios-publicos.jsp" />
<c:url var="logoutUrl" value="/logout.jsp" />
<c:choose>
  <c:when test="${empty sessionScope.userId}"><c:redirect url="/login.jsp" /></c:when>
  <c:otherwise>
    <sql:query var="activeAdmin" dataSource="jdbc/ProjectsDB">
      SELECT u.id,u.nombre_completo,r.nombre AS rol
      FROM usuarios u JOIN usuario_roles ur ON ur.usuario_id=u.id JOIN roles r ON r.id=ur.rol_id
      WHERE u.id=? AND u.estado='activo'
      ORDER BY CASE r.nombre WHEN 'administrador' THEN 1 WHEN 'estudiante' THEN 2 ELSE 3 END LIMIT 1
      <sql:param value="${sessionScope.userId}" />
    </sql:query>
    <c:choose>
      <c:when test="${empty activeAdmin.rows}">
        <c:remove var="userId" scope="session" /><c:remove var="userName" scope="session" /><c:remove var="userRole" scope="session" />
        <c:redirect url="/login.jsp" />
      </c:when>
      <c:when test="${activeAdmin.rows[0].rol eq 'estudiante'}"><c:redirect url="/index.jsp" /></c:when>
      <c:when test="${activeAdmin.rows[0].rol ne 'administrador'}"><c:redirect url="/login.jsp" /></c:when>
      <c:otherwise><c:set var="currentUserName" value="${activeAdmin.rows[0].nombre_completo}" /></c:otherwise>
    </c:choose>
  </c:otherwise>
</c:choose>

<c:if test="${empty sessionScope.csrfToken}">
  <sql:query var="newCsrf" dataSource="jdbc/ProjectsDB">SELECT LOWER(SHA2(CONCAT(UUID(), RAND(), UUID(), NOW(6)), 256)) AS token</sql:query>
  <c:set var="csrfToken" value="${newCsrf.rows[0].token}" scope="session" />
</c:if>

<c:if test="${pageContext.request.method eq 'POST'}">
  <c:set var="operationError" value="" />
  <c:set var="operationNotice" value="" />
  <c:choose>
    <c:when test="${empty sessionScope.csrfToken or empty param.csrfToken or sessionScope.csrfToken ne param.csrfToken}">
      <c:set var="operationError" value="El formulario expiró. Recarga la página e inténtalo de nuevo." />
    </c:when>
    <c:when test="${param.action eq 'create'}">
      <c:set var="roleValid" value="${param.role eq 'administrador' or param.role eq 'coordinador' or param.role eq 'docente' or param.role eq 'estudiante'}" />
      <c:set var="studentValid" value="${param.role ne 'estudiante' or (not empty param.studentCode and not empty param.programId)}" />
      <c:set var="emailValid" value="${fn:contains(fn:trim(param.email), '@') and not fn:contains(fn:trim(param.email), ' ')}" />
      <c:set var="programValid" value="${param.role ne 'estudiante'}" />
      <c:if test="${param.role eq 'estudiante' and not empty param.programId}">
        <sql:query var="selectedProgram" dataSource="jdbc/ProjectsDB">SELECT id FROM programas_academicos WHERE id=? AND activo=1<sql:param value="${param.programId}" /></sql:query>
        <c:set var="programValid" value="${not empty selectedProgram.rows}" />
      </c:if>
      <c:choose>
        <c:when test="${empty fn:trim(param.name) or fn:length(param.name) gt 160 or empty fn:trim(param.email) or fn:length(param.email) gt 190 or not emailValid or not roleValid or empty param.password or fn:length(param.password) lt 8 or fn:length(param.password) gt 200 or not studentValid or not programValid}">
          <c:set var="operationError" value="Revisa los campos obligatorios. Estudiantes requieren código y programa; la contraseña debe tener al menos 8 caracteres." />
        </c:when>
        <c:otherwise>
          <c:catch var="databaseFailure">
            <sql:transaction dataSource="jdbc/ProjectsDB">
              <sql:update var="createdCount">
                INSERT INTO usuarios (correo,nombre_completo,hash_contrasena,salt_contrasena,estado)
                SELECT LOWER(?),?,proyectos_grado_uts.pg_password_digest(?,salts.salt),salts.salt,'activo'
                FROM (SELECT LOWER(SUBSTRING(SHA2(CONCAT(UUID(),UUID(),RAND(),RAND()),256),1,32)) AS salt) salts
                <sql:param value="${fn:trim(param.email)}" />
                <sql:param value="${fn:trim(param.name)}" />
                <sql:param value="${param.password}" />
              </sql:update>
              <sql:query var="createdUserId">SELECT LAST_INSERT_ID() AS id</sql:query>
              <sql:update>
                INSERT INTO usuario_roles (usuario_id,rol_id)
                SELECT ?,id FROM roles WHERE nombre=?
                <sql:param value="${createdUserId.rows[0].id}" />
                <sql:param value="${param.role}" />
              </sql:update>
              <c:if test="${param.role eq 'estudiante'}">
                <sql:update>
                  INSERT INTO estudiantes (usuario_id,codigo_estudiantil,programa_id)
                  SELECT ?,?,id FROM programas_academicos WHERE id=? AND activo=1
                  <sql:param value="${createdUserId.rows[0].id}" />
                  <sql:param value="${fn:trim(param.studentCode)}" />
                  <sql:param value="${param.programId}" />
                </sql:update>
                <sql:query var="studentCreated">SELECT COUNT(*) AS total FROM estudiantes WHERE usuario_id=?<sql:param value="${createdUserId.rows[0].id}" /></sql:query>
                <c:if test="${studentCreated.rows[0].total ne 1}"><sql:update>DELETE FROM usuarios WHERE id=?<sql:param value="${createdUserId.rows[0].id}" /></sql:update></c:if>
              </c:if>
              <c:if test="${param.role eq 'docente'}">
                <sql:update>INSERT IGNORE INTO docentes (usuario_id) VALUES (?)<sql:param value="${createdUserId.rows[0].id}" /></sql:update>
              </c:if>
            </sql:transaction>
          </c:catch>
          <c:choose>
            <c:when test="${not empty databaseFailure}"><c:set var="operationError" value="No se pudo crear la cuenta. Revisa que el correo y el código estudiantil no estén registrados." /></c:when>
            <c:otherwise><c:set var="operationNotice" value="El usuario se creó correctamente." /></c:otherwise>
          </c:choose>
        </c:otherwise>
      </c:choose>
    </c:when>
    <c:when test="${param.action eq 'update'}">
      <c:set var="roleValid" value="${param.role eq 'administrador' or param.role eq 'coordinador' or param.role eq 'docente' or param.role eq 'estudiante'}" />
      <c:set var="studentValid" value="${param.role ne 'estudiante' or (not empty param.studentCode and not empty param.programId)}" />
      <c:set var="emailValid" value="${fn:contains(fn:trim(param.email), '@') and not fn:contains(fn:trim(param.email), ' ')}" />
      <c:set var="programValid" value="${param.role ne 'estudiante'}" />
      <c:if test="${param.role eq 'estudiante' and not empty param.programId}">
        <sql:query var="selectedProgram" dataSource="jdbc/ProjectsDB">SELECT id FROM programas_academicos WHERE id=? AND activo=1<sql:param value="${param.programId}" /></sql:query>
        <c:set var="programValid" value="${not empty selectedProgram.rows}" />
      </c:if>
      <c:choose>
        <c:when test="${empty param.userId or empty fn:trim(param.name) or fn:length(param.name) gt 160 or empty fn:trim(param.email) or fn:length(param.email) gt 190 or not emailValid or not roleValid or not studentValid or not programValid or (param.state ne 'activo' and param.state ne 'inactivo' and param.state ne 'bloqueado') or (not empty param.password and fn:length(param.password) lt 8) or fn:length(param.password) gt 200}">
          <c:set var="operationError" value="Revisa los datos del usuario, su rol, estado y contraseña." />
        </c:when>
        <c:otherwise>
          <sql:query var="updateTarget" dataSource="jdbc/ProjectsDB">
            SELECT u.id,
              (SELECT r.nombre FROM usuario_roles ur JOIN roles r ON r.id=ur.rol_id WHERE ur.usuario_id=u.id ORDER BY CASE r.nombre WHEN 'administrador' THEN 1 ELSE 2 END LIMIT 1) AS rol,
              (SELECT COUNT(*) FROM usuarios au JOIN usuario_roles aur ON aur.usuario_id=au.id JOIN roles ar ON ar.id=aur.rol_id WHERE au.estado='activo' AND ar.nombre='administrador') AS admins_activos
            FROM usuarios u WHERE u.id=?
            <sql:param value="${param.userId}" />
          </sql:query>
          <c:choose>
            <c:when test="${empty updateTarget.rows}"><c:set var="operationError" value="No se encontró el usuario." /></c:when>
            <c:when test="${param.userId eq sessionScope.userId and (param.role ne 'administrador' or param.state ne 'activo')}"><c:set var="operationError" value="No puedes quitar el rol o desactivar la cuenta con la que iniciaste sesión." /></c:when>
            <c:when test="${updateTarget.rows[0].rol eq 'administrador' and updateTarget.rows[0].admins_activos le 1 and (param.role ne 'administrador' or param.state ne 'activo')}"><c:set var="operationError" value="No puedes desactivar o cambiar el rol del último administrador activo." /></c:when>
            <c:otherwise>
              <c:catch var="databaseFailure">
                <sql:transaction dataSource="jdbc/ProjectsDB">
                  <c:choose>
                    <c:when test="${empty param.password}">
                      <sql:update var="updatedCount">
                        UPDATE usuarios SET correo=LOWER(?),nombre_completo=?,estado=? WHERE id=?
                        <sql:param value="${fn:trim(param.email)}" /><sql:param value="${fn:trim(param.name)}" />
                        <sql:param value="${param.state}" /><sql:param value="${param.userId}" />
                      </sql:update>
                    </c:when>
                    <c:otherwise>
                      <sql:update var="updatedCount">
                        UPDATE usuarios u JOIN (SELECT LOWER(SUBSTRING(SHA2(CONCAT(UUID(),UUID(),RAND(),RAND()),256),1,32)) AS salt) salts
                        SET u.correo=LOWER(?),u.nombre_completo=?,u.estado=?,u.salt_contrasena=salts.salt,
                            u.hash_contrasena=proyectos_grado_uts.pg_password_digest(?,salts.salt)
                        WHERE u.id=?
                        <sql:param value="${fn:trim(param.email)}" /><sql:param value="${fn:trim(param.name)}" />
                        <sql:param value="${param.state}" /><sql:param value="${param.password}" /><sql:param value="${param.userId}" />
                      </sql:update>
                    </c:otherwise>
                  </c:choose>
                  <c:if test="${updatedCount eq 1}">
                    <sql:update>DELETE FROM usuario_roles WHERE usuario_id=?<sql:param value="${param.userId}" /></sql:update>
                    <sql:update>
                      INSERT INTO usuario_roles(usuario_id,rol_id) SELECT ?,id FROM roles WHERE nombre=?
                      <sql:param value="${param.userId}" /><sql:param value="${param.role}" />
                    </sql:update>
                    <c:if test="${param.role eq 'estudiante'}">
                      <sql:update>
                        INSERT INTO estudiantes(usuario_id,codigo_estudiantil,programa_id) SELECT ?,?,id FROM programas_academicos WHERE id=? AND activo=1
                        ON DUPLICATE KEY UPDATE codigo_estudiantil=VALUES(codigo_estudiantil),programa_id=VALUES(programa_id)
                        <sql:param value="${param.userId}" /><sql:param value="${fn:trim(param.studentCode)}" /><sql:param value="${param.programId}" />
                      </sql:update>
                    </c:if>
                    <c:if test="${param.role eq 'docente'}">
                      <sql:update>INSERT IGNORE INTO docentes(usuario_id) VALUES (?)<sql:param value="${param.userId}" /></sql:update>
                    </c:if>
                    <c:if test="${param.userId eq sessionScope.userId}"><c:set var="userName" value="${fn:trim(param.name)}" scope="session" /></c:if>
                  </c:if>
                </sql:transaction>
              </c:catch>
              <c:choose>
                <c:when test="${not empty databaseFailure}"><c:set var="operationError" value="No se pudieron guardar los cambios. Revisa si el correo o código ya están registrados." /></c:when>
                <c:when test="${updatedCount ne 1}"><c:set var="operationError" value="No se pudieron aplicar los cambios al usuario." /></c:when>
                <c:otherwise><c:set var="operationNotice" value="Los datos del usuario se actualizaron." /></c:otherwise>
              </c:choose>
            </c:otherwise>
          </c:choose>
        </c:otherwise>
      </c:choose>
    </c:when>
    <c:when test="${param.action eq 'delete'}">
      <c:choose>
        <c:when test="${param.confirmDelete ne 'yes' or empty param.userId}"><c:set var="operationError" value="Confirma la eliminación del usuario antes de continuar." /></c:when>
        <c:when test="${param.userId eq sessionScope.userId}"><c:set var="operationError" value="No puedes eliminar la cuenta con la que iniciaste sesión." /></c:when>
        <c:otherwise>
          <sql:query var="deleteTarget" dataSource="jdbc/ProjectsDB">
            SELECT u.id,
              (SELECT r.nombre FROM usuario_roles ur JOIN roles r ON r.id=ur.rol_id WHERE ur.usuario_id=u.id ORDER BY CASE r.nombre WHEN 'administrador' THEN 1 ELSE 2 END LIMIT 1) AS rol,
              (SELECT COUNT(*) FROM usuarios au JOIN usuario_roles aur ON aur.usuario_id=au.id JOIN roles ar ON ar.id=aur.rol_id WHERE au.estado='activo' AND ar.nombre='administrador') AS admins_activos
            FROM usuarios u WHERE u.id=?
            <sql:param value="${param.userId}" />
          </sql:query>
          <c:choose>
            <c:when test="${empty deleteTarget.rows}"><c:set var="operationError" value="No se encontró un usuario con ese identificador." /></c:when>
            <c:when test="${deleteTarget.rows[0].rol eq 'administrador' and deleteTarget.rows[0].admins_activos le 1}"><c:set var="operationError" value="No puedes eliminar al último administrador activo." /></c:when>
            <c:otherwise>
              <c:catch var="databaseFailure">
                <sql:update var="deleteCount" dataSource="jdbc/ProjectsDB">
                  UPDATE usuarios SET estado='inactivo' WHERE id=? AND estado&lt;&gt;'inactivo'
                  <sql:param value="${param.userId}" />
                </sql:update>
              </c:catch>
              <c:choose>
                <c:when test="${not empty databaseFailure or deleteCount ne 1}"><c:set var="operationError" value="No se pudo desactivar este usuario." /></c:when>
                <c:otherwise><c:set var="operationNotice" value="Usuario eliminado: su cuenta se desactivó y se conservó su historial." /></c:otherwise>
              </c:choose>
            </c:otherwise>
          </c:choose>
        </c:otherwise>
      </c:choose>
    </c:when>
    <c:otherwise><c:set var="operationError" value="La acción solicitada no es válida." /></c:otherwise>
  </c:choose>
  <c:if test="${not empty operationError}"><c:set var="flashError" value="${operationError}" scope="session" /></c:if>
  <c:if test="${not empty operationNotice}"><c:set var="flashNotice" value="${operationNotice}" scope="session" /></c:if>
  <c:redirect url="/admin-usuarios.jsp" />
</c:if>

<c:set var="flashError" value="${sessionScope.flashError}" />
<c:set var="flashNotice" value="${sessionScope.flashNotice}" />
<c:remove var="flashError" scope="session" />
<c:remove var="flashNotice" scope="session" />
<c:if test="${empty sessionScope.csrfToken}">
  <sql:query var="newCsrf" dataSource="jdbc/ProjectsDB">SELECT LOWER(SHA2(CONCAT(UUID(), RAND(), UUID(), NOW(6)), 256)) AS token</sql:query>
  <c:set var="csrfToken" value="${newCsrf.rows[0].token}" scope="session" />
</c:if>
<sql:query var="programRows" dataSource="jdbc/ProjectsDB">SELECT id,nombre FROM programas_academicos WHERE activo=1 ORDER BY nombre</sql:query>
<sql:query var="userRows" dataSource="jdbc/ProjectsDB">
  SELECT u.id,u.nombre_completo,u.correo,u.estado,
    (SELECT r.nombre FROM usuario_roles ur JOIN roles r ON r.id=ur.rol_id WHERE ur.usuario_id=u.id ORDER BY CASE r.nombre WHEN 'administrador' THEN 1 WHEN 'coordinador' THEN 2 WHEN 'docente' THEN 3 ELSE 4 END LIMIT 1) AS rol,
    e.codigo_estudiantil,e.programa_id
  FROM usuarios u LEFT JOIN estudiantes e ON e.usuario_id=u.id ORDER BY u.id DESC
</sql:query>

<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#f5f7f6">
  <title>Administrar usuarios | Proyectos de grado UTS</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="${stylesUrl}">
</head>
<body>
  <div class="app-shell admin-shell">
    <aside class="sidebar admin-sidebar">
      <a class="brand sidebar-brand" href="${adminUrl}" aria-label="UTS Administración de usuarios">
        <span class="brand-mark" aria-hidden="true"><span>U</span><span>T</span><span>S</span></span>
        <span class="brand-copy"><strong>UTS</strong><span>Proyectos de grado</span></span>
      </a>
      <div class="sidebar-label">ADMINISTRACIÓN</div>
      <nav class="side-nav" aria-label="Menú de administración">
        <a class="nav-link active" href="${adminUrl}" aria-current="page">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><circle cx="9" cy="8" r="3.5" stroke="currentColor" stroke-width="1.7"/><path d="M3 20v-1.5A4.5 4.5 0 0 1 7.5 14h3a4.5 4.5 0 0 1 4.5 4.5V20M17 4.8a3.5 3.5 0 0 1 0 6.4m2 3.3a4 4 0 0 1 2 3.5V20" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>
          Gestión de usuarios
        </a>
        <a class="nav-link" href="${publicUsersUrl}">
          Directorio de usuarios
        </a>
      </nav>
      <div class="sidebar-bottom">
        <div class="admin-security-card"><span aria-hidden="true">✓</span><strong>Acceso restringido</strong><p>Disponible únicamente para cuentas administradoras.</p></div>
        <div class="sidebar-version">PLATAFORMA DE PROYECTOS <span>v1.0</span></div>
      </div>
    </aside>

    <section class="main-area">
      <header class="topbar">
        <div class="breadcrumb"><span>Administración</span><span class="crumb-slash">/</span><strong>Usuarios</strong></div>
        <div class="topbar-actions">
          <span class="admin-role-badge">ADMINISTRADOR</span><span class="topbar-divider"></span>
          <span class="profile-button"><span class="avatar"><c:out value="${fn:toUpperCase(fn:substring(currentUserName,0,1))}" /></span><span class="profile-info"><strong><c:out value="${currentUserName}" /></strong><small>Administrador</small></span></span>
          <a class="logout-link" href="${logoutUrl}">Cerrar sesión</a>
        </div>
      </header>
      <main class="admin-page">
        <section class="admin-heading">
          <div><p class="section-overline"><span></span> CONTROL DE ACCESO</p><h1>Gestión de usuarios</h1><p>Crea cuentas, actualiza sus datos y administra sus roles en la plataforma.</p></div>
          <div class="admin-total"><strong><c:out value="${fn:length(userRows.rows)}" /></strong><span>cuentas registradas</span></div>
        </section>
        <c:if test="${not empty flashError}"><div class="admin-alert admin-alert-error" role="alert"><strong>No se completó la operación.</strong><span><c:out value="${flashError}" /></span></div></c:if>
        <c:if test="${not empty flashNotice}"><div class="admin-alert admin-alert-success" role="status"><strong>Operación completada</strong><span><c:out value="${flashNotice}" /></span></div></c:if>

        <section class="admin-create-card" aria-labelledby="createUserTitle">
          <div class="admin-card-heading"><span class="admin-card-icon" aria-hidden="true">+</span><div><h2 id="createUserTitle">Crear usuario</h2><p>Registra una cuenta nueva y asigna su rol.</p></div></div>
          <form class="admin-create-form" action="${adminUrl}" method="post">
            <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="action" value="create">
            <label class="admin-field" for="newName"><span>Nombre completo <i>*</i></span><input id="newName" name="name" type="text" maxlength="160" autocomplete="name" required></label>
            <label class="admin-field" for="newEmail"><span>Correo institucional <i>*</i></span><input id="newEmail" name="email" type="email" maxlength="190" autocomplete="email" required></label>
            <label class="admin-field" for="newRole"><span>Rol <i>*</i></span><select id="newRole" name="role" required><option value="">Selecciona un rol</option><option value="estudiante">Estudiante</option><option value="docente">Docente</option><option value="coordinador">Coordinador</option><option value="administrador">Administrador</option></select></label>
            <label class="admin-field" for="newPassword"><span>Contraseña inicial <i>*</i></span><input id="newPassword" name="password" type="password" minlength="8" maxlength="200" autocomplete="new-password" required><small>Mínimo 8 caracteres.</small></label>
            <label class="admin-field" for="newStudentCode"><span>Código estudiantil <small>(si aplica)</small></span><input id="newStudentCode" name="studentCode" type="text" maxlength="40"></label>
            <label class="admin-field" for="newProgram"><span>Programa académico <small>(si aplica)</small></span><select id="newProgram" name="programId"><option value="">Selecciona un programa</option><c:forEach var="program" items="${programRows.rows}"><option value="<c:out value='${program.id}' />"><c:out value="${program.nombre}" /></option></c:forEach></select></label>
            <div class="admin-create-submit"><button class="button button-primary" type="submit">Crear cuenta <span aria-hidden="true">→</span></button></div>
            <p class="admin-form-note">Para estudiantes se requieren código y programa. La contraseña se almacena con hash y sal.</p>
          </form>
        </section>

        <section class="admin-users-section" aria-labelledby="usersListTitle">
          <div class="admin-list-heading"><div><h2 id="usersListTitle">Cuentas registradas</h2><p>Edita el perfil o desactiva una cuenta que ya no deba acceder.</p></div><span class="admin-list-count"><c:out value="${fn:length(userRows.rows)}" /> usuarios</span></div>
          <c:choose>
            <c:when test="${empty userRows.rows}"><div class="admin-empty-state"><strong>No hay usuarios registrados.</strong><span>Usa el formulario para crear la primera cuenta.</span></div></c:when>
            <c:otherwise>
              <div class="admin-user-list">
                <c:forEach var="user" items="${userRows.rows}">
                  <article class="admin-user-card">
                    <div class="admin-user-card-heading"><span class="admin-user-avatar"><c:out value="${fn:toUpperCase(fn:substring(user.nombre_completo,0,1))}" /></span><div class="admin-user-identity"><strong><c:out value="${user.nombre_completo}" /></strong><span><c:out value="${user.correo}" /></span></div><span class="admin-state admin-state-${user.estado}"><c:out value="${user.estado}" /></span></div>
                    <form class="admin-edit-form" action="${adminUrl}" method="post">
                      <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="action" value="update"><input type="hidden" name="userId" value="<c:out value='${user.id}' />">
                      <label class="admin-field"><span>Nombre</span><input name="name" type="text" maxlength="160" value="<c:out value='${user.nombre_completo}' />" required></label>
                      <label class="admin-field"><span>Correo</span><input name="email" type="email" maxlength="190" value="<c:out value='${user.correo}' />" required></label>
                      <label class="admin-field"><span>Rol</span><select name="role" required><option value="estudiante" ${user.rol eq 'estudiante' ? 'selected' : ''}>Estudiante</option><option value="docente" ${user.rol eq 'docente' ? 'selected' : ''}>Docente</option><option value="coordinador" ${user.rol eq 'coordinador' ? 'selected' : ''}>Coordinador</option><option value="administrador" ${user.rol eq 'administrador' ? 'selected' : ''}>Administrador</option></select></label>
                      <label class="admin-field"><span>Estado</span><select name="state" required><option value="activo" ${user.estado eq 'activo' ? 'selected' : ''}>Activo</option><option value="inactivo" ${user.estado eq 'inactivo' ? 'selected' : ''}>Inactivo</option><option value="bloqueado" ${user.estado eq 'bloqueado' ? 'selected' : ''}>Bloqueado</option></select></label>
                      <label class="admin-field"><span>Código estudiantil <small>(si aplica)</small></span><input name="studentCode" type="text" maxlength="40" value="<c:out value='${user.codigo_estudiantil}' />"></label>
                      <label class="admin-field"><span>Programa <small>(si aplica)</small></span><select name="programId"><option value="">Selecciona un programa</option><c:forEach var="program" items="${programRows.rows}"><option value="<c:out value='${program.id}' />" ${user.programa_id eq program.id ? 'selected' : ''}><c:out value="${program.nombre}" /></option></c:forEach></select></label>
                      <label class="admin-field admin-password-field"><span>Nueva contraseña <small>(opcional)</small></span><input name="password" type="password" minlength="8" maxlength="200" autocomplete="new-password" placeholder="Dejar en blanco para conservarla"></label>
                      <div class="admin-edit-submit"><button class="button button-secondary" type="submit">Guardar cambios</button></div>
                    </form>
                    <c:if test="${user.estado ne 'inactivo'}"><form class="admin-delete-form" action="${adminUrl}" method="post"><input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="action" value="delete"><input type="hidden" name="userId" value="<c:out value='${user.id}' />"><label><input type="checkbox" name="confirmDelete" value="yes" required> Confirmo desactivar esta cuenta</label><button class="admin-delete-button" type="submit">Eliminar usuario</button></form></c:if>
                  </article>
                </c:forEach>
              </div>
            </c:otherwise>
          </c:choose>
        </section>
        <footer class="dashboard-footer"><span>Universitaria Tecnológica de Santander</span><span>Las cuentas inactivas conservan su historial y pueden reactivarse.</span></footer>
      </main>
    </section>
  </div>
</body>
</html>

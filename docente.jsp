<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<c:choose>
  <c:when test="${param.view eq 'ideas' or param.view eq 'historial'}"><c:set var="currentSection" value="${param.view}" /></c:when>
  <c:otherwise><c:set var="currentSection" value="proyectos" /></c:otherwise>
</c:choose>
<c:choose>
  <c:when test="${empty sessionScope.userId}"><c:redirect url="/login.jsp" /></c:when>
  <c:otherwise>
    <sql:query var="activeTeacher" dataSource="jdbc/ProjectsDB">
      SELECT u.id,u.nombre_completo,r.nombre AS rol
      FROM usuarios u JOIN usuario_roles ur ON ur.usuario_id=u.id JOIN roles r ON r.id=ur.rol_id
      WHERE u.id=? AND u.estado='activo'
      ORDER BY CASE r.nombre WHEN 'administrador' THEN 1 WHEN 'coordinador' THEN 2 WHEN 'docente' THEN 3 ELSE 4 END
      LIMIT 1
      <sql:param value="${sessionScope.userId}" />
    </sql:query>
    <c:choose>
      <c:when test="${empty activeTeacher.rows}">
        <c:remove var="userId" scope="session" /><c:remove var="userName" scope="session" /><c:remove var="userRole" scope="session" />
        <c:redirect url="/login.jsp" />
      </c:when>
      <c:when test="${activeTeacher.rows[0].rol eq 'administrador'}"><c:redirect url="/admin-usuarios.jsp" /></c:when>
      <c:when test="${activeTeacher.rows[0].rol eq 'coordinador'}"><c:redirect url="/coordinador-ideas.jsp" /></c:when>
      <c:when test="${activeTeacher.rows[0].rol ne 'docente'}"><c:redirect url="/index.jsp" /></c:when>
      <c:otherwise><c:set var="currentUserName" value="${activeTeacher.rows[0].nombre_completo}" /></c:otherwise>
    </c:choose>
  </c:otherwise>
</c:choose>
<c:if test="${empty sessionScope.csrfToken}">
  <sql:query var="newCsrf" dataSource="jdbc/ProjectsDB">SELECT LOWER(SHA2(CONCAT(UUID(), RAND(), UUID(), NOW(6)), 256)) AS token</sql:query>
  <c:set var="csrfToken" value="${newCsrf.rows[0].token}" scope="session" />
</c:if>
<c:if test="${pageContext.request.method eq 'POST'}">
  <c:choose>
    <c:when test="${empty sessionScope.csrfToken or empty param.csrfToken or sessionScope.csrfToken ne param.csrfToken}">
      <c:set var="flashError" value="El formulario expiró. Recarga la página e inténtalo de nuevo." scope="session" />
    </c:when>
    <c:when test="${param.action eq 'proposeIdea'}">
      <c:choose>
        <c:when test="${empty fn:trim(param.title) or fn:length(param.title) gt 120 or empty fn:trim(param.problem) or fn:length(param.problem) gt 1200 or empty fn:trim(param.description) or fn:length(param.description) gt 1800 or fn:length(param.resources) gt 800 or empty param.programId or empty param.areaId}">
          <c:set var="flashError" value="Completa los campos obligatorios y verifica los límites de caracteres." scope="session" />
        </c:when>
        <c:otherwise>
          <sql:query var="validAcademicChoices" dataSource="jdbc/ProjectsDB">
            SELECT (SELECT COUNT(*) FROM programas_academicos WHERE id=? AND activo=1) AS programa_valido,
              (SELECT COUNT(*) FROM areas_tematicas WHERE id=? AND activa=1) AS area_valida
            <sql:param value="${param.programId}" />
            <sql:param value="${param.areaId}" />
          </sql:query>
          <c:choose>
            <c:when test="${validAcademicChoices.rows[0].programa_valido ne 1 or validAcademicChoices.rows[0].area_valida ne 1}">
              <c:set var="flashError" value="Selecciona un programa y un área temática activos." scope="session" />
            </c:when>
            <c:otherwise>
              <c:catch var="proposalFailure">
                <sql:transaction dataSource="jdbc/ProjectsDB">
                  <sql:update var="createdIdea">
                    INSERT INTO ideas (codigo,titulo,problema,descripcion,recursos_tecnologias,tipo,estado,programa_id,area_id,proponente_id,enviada_en)
                    VALUES (CONCAT('IDEA-',UPPER(SUBSTRING(REPLACE(UUID(),'-',''),1,16))),?,?,?,NULLIF(?,''),'institucional','pendiente_revision',?,?,?,NOW())
                    <sql:param value="${fn:trim(param.title)}" />
                    <sql:param value="${fn:trim(param.problem)}" />
                    <sql:param value="${fn:trim(param.description)}" />
                    <sql:param value="${fn:trim(param.resources)}" />
                    <sql:param value="${param.programId}" />
                    <sql:param value="${param.areaId}" />
                    <sql:param value="${sessionScope.userId}" />
                  </sql:update>
                  <sql:query var="createdIdeaId">SELECT LAST_INSERT_ID() AS id</sql:query>
                  <sql:update>
                    INSERT INTO direcciones_ideas (idea_id,director_id,asignado_por)
                    SELECT ?,d.usuario_id,d.usuario_id FROM docentes d
                    WHERE d.usuario_id=?
                    <sql:param value="${createdIdeaId.rows[0].id}" />
                    <sql:param value="${sessionScope.userId}" />
                  </sql:update>
                </sql:transaction>
              </c:catch>
              <c:choose>
                <c:when test="${not empty proposalFailure}">
                  <c:set var="flashError" value="No se pudo enviar la idea al banco. Inténtalo nuevamente." scope="session" />
                </c:when>
                <c:when test="${createdIdea ne 1}">
                  <c:set var="flashError" value="No se pudo registrar la propuesta con tu perfil docente." scope="session" />
                </c:when>
                <c:otherwise>
                  <c:set var="flashNotice" value="Tu idea se envió a coordinación para su aprobación. Quedaste registrado como director." scope="session" />
                </c:otherwise>
              </c:choose>
            </c:otherwise>
          </c:choose>
        </c:otherwise>
      </c:choose>
    </c:when>
    <c:when test="${param.action eq 'reviewFinalProject'}">
      <c:choose>
        <c:when test="${empty param.finalProjectId or (param.decision ne 'aprobado' and param.decision ne 'aplazado' and param.decision ne 'rechazado') or fn:length(param.observations) gt 1200}">
          <c:set var="flashError" value="La decisión no es válida. Revisa el proyecto final e inténtalo de nuevo." scope="session" />
        </c:when>
        <c:otherwise>
          <c:set var="updatedFinalProject" value="0" />
          <c:set var="finalProjectReviewStage" value="" />
          <c:catch var="finalProjectReviewFailure">
            <sql:transaction dataSource="jdbc/ProjectsDB">
              <sql:query var="finalProjectForReview">
                SELECT pf.estado,
                  CASE WHEN pf.estado='pendiente_director' THEN 'director' ELSE 'evaluador' END AS etapa
                FROM proyectos_finales pf
                JOIN anteproyectos ap ON ap.id=pf.anteproyecto_id
                LEFT JOIN direcciones_ideas d ON d.idea_id=ap.idea_id
                LEFT JOIN evaluadores_ideas ei ON ei.idea_id=ap.idea_id
                WHERE pf.id=? AND (
                  (pf.estado='pendiente_director' AND d.director_id=?)
                  OR (pf.estado='pendiente_evaluador' AND ei.evaluador_id=?)
                )
                FOR UPDATE
                <sql:param value="${param.finalProjectId}" />
                <sql:param value="${sessionScope.userId}" />
                <sql:param value="${sessionScope.userId}" />
              </sql:query>
              <c:if test="${not empty finalProjectForReview.rows}">
                <c:set var="finalProjectReviewStage" value="${finalProjectForReview.rows[0].etapa}" />
                <sql:update var="updatedFinalProject">
                  UPDATE proyectos_finales pf
                  JOIN anteproyectos ap ON ap.id=pf.anteproyecto_id
                  LEFT JOIN direcciones_ideas d ON d.idea_id=ap.idea_id
                  LEFT JOIN evaluadores_ideas ei ON ei.idea_id=ap.idea_id
                  SET pf.estado=CASE WHEN pf.estado='pendiente_director' AND ?='aprobado'
                    THEN 'pendiente_evaluador' ELSE ? END,pf.revisado_en=NOW()
                  WHERE pf.id=? AND (
                    (pf.estado='pendiente_director' AND d.director_id=?)
                    OR (pf.estado='pendiente_evaluador' AND ei.evaluador_id=?)
                  )
                  <sql:param value="${param.decision}" />
                  <sql:param value="${param.decision}" />
                  <sql:param value="${param.finalProjectId}" />
                  <sql:param value="${sessionScope.userId}" />
                  <sql:param value="${sessionScope.userId}" />
                </sql:update>
                <c:if test="${updatedFinalProject eq 1}">
                  <sql:update>
                    INSERT INTO revisiones_proyectos_finales (proyecto_final_id,revisor_id,etapa,decision,observaciones)
                    VALUES (?,?,?,?,NULLIF(?, ''))
                    <sql:param value="${param.finalProjectId}" />
                    <sql:param value="${sessionScope.userId}" />
                    <sql:param value="${finalProjectReviewStage}" />
                    <sql:param value="${param.decision}" />
                    <sql:param value="${fn:trim(param.observations)}" />
                  </sql:update>
                </c:if>
              </c:if>
            </sql:transaction>
          </c:catch>
          <c:choose>
            <c:when test="${not empty finalProjectReviewFailure}"><c:set var="flashError" value="No se pudo guardar la decisión sobre el proyecto final." scope="session" /></c:when>
            <c:when test="${updatedFinalProject ne 1}"><c:set var="flashError" value="El proyecto final ya fue revisado o no está asignado a tu cuenta." scope="session" /></c:when>
            <c:when test="${param.decision eq 'aprobado' and finalProjectReviewStage eq 'director'}"><c:set var="flashNotice" value="El proyecto final fue aprobado por el director y enviado al evaluador." scope="session" /></c:when>
            <c:when test="${param.decision eq 'aprobado'}"><c:set var="flashNotice" value="El proyecto final fue aprobado por el director y el evaluador." scope="session" /></c:when>
            <c:when test="${param.decision eq 'aplazado' and finalProjectReviewStage eq 'director'}"><c:set var="flashNotice" value="El proyecto final quedó aplazado por el director. El estudiante podrá corregirlo y reenviarlo a dirección." scope="session" /></c:when>
            <c:when test="${param.decision eq 'aplazado'}"><c:set var="flashNotice" value="El proyecto final quedó aplazado por el evaluador. El estudiante podrá corregirlo y reenviarlo para evaluación." scope="session" /></c:when>
            <c:when test="${finalProjectReviewStage eq 'director'}"><c:set var="flashNotice" value="El proyecto final fue rechazado por el director." scope="session" /></c:when>
            <c:otherwise><c:set var="flashNotice" value="El proyecto final fue rechazado por el evaluador." scope="session" /></c:otherwise>
          </c:choose>
        </c:otherwise>
      </c:choose>
    </c:when>
    <c:when test="${param.action eq 'reviewAnteproyecto'}">
      <c:choose>
        <c:when test="${empty param.anteproyectoId or (param.decision ne 'aprobado' and param.decision ne 'aplazado' and param.decision ne 'rechazado') or fn:length(param.observations) gt 1200}">
          <c:set var="flashError" value="La decisión no es válida. Revisa el anteproyecto e inténtalo de nuevo." scope="session" />
        </c:when>
        <c:otherwise>
          <c:set var="updatedAnteproyecto" value="0" />
          <c:set var="reviewStage" value="" />
          <c:catch var="reviewFailure">
            <sql:transaction dataSource="jdbc/ProjectsDB">
              <sql:query var="anteproyectoForReview">
                SELECT ap.estado,
                  CASE WHEN ap.estado='pendiente_revision' THEN 'director' ELSE 'evaluador' END AS etapa
                FROM anteproyectos ap
                WHERE ap.id=? AND (
                  (ap.director_id=? AND ap.estado='pendiente_revision')
                  OR (ap.estado='pendiente_evaluador' AND EXISTS (
                    SELECT 1 FROM evaluadores_ideas ei
                    WHERE ei.idea_id=ap.idea_id AND ei.evaluador_id=?
                  ))
                )
                FOR UPDATE
                <sql:param value="${param.anteproyectoId}" />
                <sql:param value="${sessionScope.userId}" />
                <sql:param value="${sessionScope.userId}" />
              </sql:query>
              <c:if test="${not empty anteproyectoForReview.rows}">
                <c:set var="reviewStage" value="${anteproyectoForReview.rows[0].etapa}" />
              <sql:update var="updatedAnteproyecto">
                UPDATE anteproyectos
                SET estado=CASE WHEN estado='pendiente_revision' AND ?='aprobado'
                  THEN 'pendiente_evaluador' ELSE ? END,revisado_en=NOW()
                WHERE id=? AND (
                  (director_id=? AND estado='pendiente_revision')
                  OR (estado='pendiente_evaluador' AND EXISTS (
                    SELECT 1 FROM evaluadores_ideas ei
                    WHERE ei.idea_id=anteproyectos.idea_id AND ei.evaluador_id=?
                  ))
                )
                <sql:param value="${param.decision}" />
                <sql:param value="${param.decision}" />
                <sql:param value="${param.anteproyectoId}" />
                <sql:param value="${sessionScope.userId}" />
                <sql:param value="${sessionScope.userId}" />
              </sql:update>
              <c:if test="${updatedAnteproyecto eq 1}">
                <sql:update>
                  INSERT INTO revisiones_anteproyectos (anteproyecto_id,director_id,etapa,decision,observaciones)
                  VALUES (?,?,?,?,NULLIF(?, ''))
                  <sql:param value="${param.anteproyectoId}" />
                  <sql:param value="${sessionScope.userId}" />
                  <sql:param value="${reviewStage}" />
                  <sql:param value="${param.decision}" />
                  <sql:param value="${fn:trim(param.observations)}" />
                </sql:update>
              </c:if>
              </c:if>
            </sql:transaction>
          </c:catch>
          <c:choose>
            <c:when test="${not empty reviewFailure}">
              <c:set var="flashError" value="No se pudo guardar la decisión. Inténtalo nuevamente." scope="session" />
            </c:when>
            <c:when test="${updatedAnteproyecto ne 1}">
              <c:set var="flashError" value="El anteproyecto ya fue revisado o no está asignado a tu cuenta." scope="session" />
            </c:when>
            <c:when test="${param.decision eq 'aprobado' and reviewStage eq 'director'}">
              <c:set var="flashNotice" value="El anteproyecto fue aprobado por dirección y enviado al evaluador para su decisión." scope="session" />
            </c:when>
            <c:when test="${param.decision eq 'aprobado'}">
              <c:set var="flashNotice" value="El anteproyecto fue aprobado por dirección y evaluación." scope="session" />
            </c:when>
            <c:when test="${param.decision eq 'aplazado'}">
              <c:set var="flashNotice" value="El anteproyecto quedó aplazado. El estudiante podrá corregirlo y volverá a revisión del director." scope="session" />
            </c:when>
            <c:otherwise>
              <c:set var="flashNotice" value="El anteproyecto fue rechazado." scope="session" />
            </c:otherwise>
          </c:choose>
        </c:otherwise>
      </c:choose>
    </c:when>
    <c:otherwise>
      <c:set var="flashError" value="La operación solicitada no es válida." scope="session" />
    </c:otherwise>
  </c:choose>
  <c:redirect url="/docente.jsp?view=${currentSection}" />
</c:if>
<c:if test="${not empty sessionScope.flashNotice}"><c:set var="pageNotice" value="${sessionScope.flashNotice}" /><c:remove var="flashNotice" scope="session" /></c:if>
<c:if test="${not empty sessionScope.flashError}"><c:set var="pageError" value="${sessionScope.flashError}" /><c:remove var="flashError" scope="session" /></c:if>
<sql:query var="programRows" dataSource="jdbc/ProjectsDB">SELECT id,nombre FROM programas_academicos WHERE activo=1 ORDER BY nombre</sql:query>
<sql:query var="areaRows" dataSource="jdbc/ProjectsDB">SELECT id,nombre FROM areas_tematicas WHERE activa=1 ORDER BY nombre</sql:query>
<sql:query var="pendingAnteproyectos" dataSource="jdbc/ProjectsDB">
  SELECT ap.id,ap.titulo,ap.descripcion,ap.enlace_drive,ap.enviado_en,
    i.codigo AS idea_codigo,i.titulo AS idea_titulo,i.problema AS idea_problema,
    i.descripcion AS idea_descripcion,i.objetivos AS idea_objetivos,
    i.recursos_tecnologias AS idea_recursos,i.beneficiarios AS idea_beneficiarios,
    idea_program.nombre AS idea_programa,idea_area.nombre AS idea_area,
    u.nombre_completo AS estudiante,e.codigo_estudiantil,p.nombre AS programa,
    partner.nombre_completo AS integrante,
    'director' AS etapa
  FROM anteproyectos ap
  JOIN ideas i ON i.id=ap.idea_id
  JOIN programas_academicos idea_program ON idea_program.id=i.programa_id
  JOIN areas_tematicas idea_area ON idea_area.id=i.area_id
  JOIN usuarios u ON u.id=ap.estudiante_id
  JOIN estudiantes e ON e.usuario_id=ap.estudiante_id
  JOIN programas_academicos p ON p.id=e.programa_id
  LEFT JOIN solicitudes_ideas team_request ON team_request.idea_id=ap.idea_id
    AND team_request.estudiante_id=ap.estudiante_id AND team_request.estado='aprobada'
  LEFT JOIN usuarios partner ON partner.id=team_request.integrante_id
  WHERE ap.director_id=? AND ap.estado='pendiente_revision'
  UNION ALL
  SELECT ap.id,ap.titulo,ap.descripcion,ap.enlace_drive,ap.enviado_en,
    i.codigo AS idea_codigo,i.titulo AS idea_titulo,i.problema AS idea_problema,
    i.descripcion AS idea_descripcion,i.objetivos AS idea_objetivos,
    i.recursos_tecnologias AS idea_recursos,i.beneficiarios AS idea_beneficiarios,
    idea_program.nombre AS idea_programa,idea_area.nombre AS idea_area,
    u.nombre_completo AS estudiante,e.codigo_estudiantil,p.nombre AS programa,
    partner.nombre_completo AS integrante,
    'evaluador' AS etapa
  FROM anteproyectos ap
  JOIN evaluadores_ideas ei ON ei.idea_id=ap.idea_id AND ei.evaluador_id=?
  JOIN ideas i ON i.id=ap.idea_id
  JOIN programas_academicos idea_program ON idea_program.id=i.programa_id
  JOIN areas_tematicas idea_area ON idea_area.id=i.area_id
  JOIN usuarios u ON u.id=ap.estudiante_id
  JOIN estudiantes e ON e.usuario_id=ap.estudiante_id
  JOIN programas_academicos p ON p.id=e.programa_id
  LEFT JOIN solicitudes_ideas team_request ON team_request.idea_id=ap.idea_id
    AND team_request.estudiante_id=ap.estudiante_id AND team_request.estado='aprobada'
  LEFT JOIN usuarios partner ON partner.id=team_request.integrante_id
  WHERE ap.estado='pendiente_evaluador'
  ORDER BY enviado_en ASC,id ASC
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<sql:query var="pendingFinalProjects" dataSource="jdbc/ProjectsDB">
  SELECT pf.id,pf.titulo,pf.descripcion,pf.enlace_drive,pf.enviado_en,pf.estado,
    i.codigo AS idea_codigo,i.titulo AS idea_titulo,i.problema AS idea_problema,
    i.descripcion AS idea_descripcion,i.objetivos AS idea_objetivos,
    i.recursos_tecnologias AS idea_recursos,i.beneficiarios AS idea_beneficiarios,
    idea_program.nombre AS idea_programa,idea_area.nombre AS idea_area,
    u.nombre_completo AS estudiante,
    e.codigo_estudiantil,p.nombre AS programa,partner.nombre_completo AS integrante,
    CASE WHEN pf.estado='pendiente_director' THEN 'director' ELSE 'evaluador' END AS etapa
  FROM proyectos_finales pf
  JOIN anteproyectos ap ON ap.id=pf.anteproyecto_id
  JOIN ideas i ON i.id=ap.idea_id
  JOIN programas_academicos idea_program ON idea_program.id=i.programa_id
  JOIN areas_tematicas idea_area ON idea_area.id=i.area_id
  JOIN usuarios u ON u.id=ap.estudiante_id
  JOIN estudiantes e ON e.usuario_id=ap.estudiante_id
  JOIN programas_academicos p ON p.id=e.programa_id
  LEFT JOIN solicitudes_ideas team_request ON team_request.idea_id=ap.idea_id
    AND team_request.estudiante_id=ap.estudiante_id AND team_request.estado='aprobada'
  LEFT JOIN usuarios partner ON partner.id=team_request.integrante_id
  LEFT JOIN direcciones_ideas d ON d.idea_id=ap.idea_id
  LEFT JOIN evaluadores_ideas ei ON ei.idea_id=ap.idea_id
  WHERE (pf.estado='pendiente_director' AND d.director_id=?)
    OR (pf.estado='pendiente_evaluador' AND ei.evaluador_id=?)
  ORDER BY pf.enviado_en ASC,pf.id ASC
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<sql:query var="teacherProjectPhases" dataSource="jdbc/ProjectsDB">
  SELECT s.id,s.estado AS solicitud_estado,s.pago_verificado,i.codigo AS idea_codigo,i.titulo AS idea_titulo,
    student.nombre_completo AS estudiante,partner.nombre_completo AS integrante,
    CASE WHEN d.director_id=? THEN 'director' ELSE 'evaluador' END AS rol_revision,
    CASE
      WHEN s.estado<>'aprobada' OR s.pago_verificado=0 THEN 1
      WHEN final_project.estado='pendiente_director' THEN 5
      WHEN final_project.estado='rechazado' AND latest_final_review.etapa='director' THEN 5
      WHEN final_project.estado='aplazado' THEN 4
      WHEN final_project.estado IN ('pendiente_evaluador','aprobado') THEN 6
      WHEN final_project.estado='rechazado' AND latest_final_review.etapa='evaluador' THEN 6
      WHEN ap.estado='aplazado' AND latest_review.etapa='evaluador' THEN 1
      WHEN ap.estado='pendiente_revision' THEN 2
      WHEN ap.estado='pendiente_evaluador' THEN 3
      WHEN ap.estado='aprobado' THEN 4
      WHEN ap.estado='aplazado' THEN 2
      WHEN ap.estado='rechazado' THEN CASE WHEN latest_review.etapa='evaluador' THEN 3 ELSE 2 END
      ELSE 1
    END AS fase_actual,
    ap.estado AS anteproyecto_estado
  FROM solicitudes_ideas s
  JOIN ideas i ON i.id=s.idea_id
  JOIN direcciones_ideas d ON d.idea_id=i.id
  LEFT JOIN evaluadores_ideas ei ON ei.idea_id=i.id
  LEFT JOIN anteproyectos ap ON ap.idea_id=i.id AND ap.estudiante_id=s.estudiante_id
  LEFT JOIN proyectos_finales final_project ON final_project.anteproyecto_id=ap.id
  LEFT JOIN revisiones_proyectos_finales latest_final_review ON latest_final_review.id=(
    SELECT MAX(review.id) FROM revisiones_proyectos_finales review WHERE review.proyecto_final_id=final_project.id
  )
  LEFT JOIN revisiones_anteproyectos latest_review ON latest_review.id=(
    SELECT MAX(review.id) FROM revisiones_anteproyectos review WHERE review.anteproyecto_id=ap.id
  )
  JOIN usuarios student ON student.id=s.estudiante_id
  LEFT JOIN usuarios partner ON partner.id=s.integrante_id
  WHERE s.estado IN ('pendiente','aprobada')
    AND (d.director_id=? OR ei.evaluador_id=?)
    AND (final_project.id IS NULL OR final_project.estado<>'aprobado')
  ORDER BY s.creada_en DESC,s.id DESC
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<sql:query var="completedTeacherProjects" dataSource="jdbc/ProjectsDB">
  SELECT pf.id,pf.titulo,pf.descripcion,pf.enlace_drive,pf.enviado_en,latest_review.revisada_en AS aprobado_en,
    i.codigo AS idea_codigo,i.titulo AS idea_titulo,student.nombre_completo AS estudiante,
    partner.nombre_completo AS integrante,p.nombre AS programa,
    CASE WHEN d.director_id=? THEN 'Director' ELSE 'Evaluador' END AS rol_revision
  FROM proyectos_finales pf
  JOIN anteproyectos ap ON ap.id=pf.anteproyecto_id
  JOIN ideas i ON i.id=ap.idea_id
  JOIN usuarios student ON student.id=ap.estudiante_id
  JOIN estudiantes e ON e.usuario_id=ap.estudiante_id
  JOIN programas_academicos p ON p.id=e.programa_id
  LEFT JOIN solicitudes_ideas team_request ON team_request.idea_id=ap.idea_id
    AND team_request.estudiante_id=ap.estudiante_id AND team_request.estado='aprobada'
  LEFT JOIN usuarios partner ON partner.id=team_request.integrante_id
  LEFT JOIN direcciones_ideas d ON d.idea_id=ap.idea_id
  LEFT JOIN evaluadores_ideas ei ON ei.idea_id=ap.idea_id
  JOIN revisiones_proyectos_finales latest_review ON latest_review.id=(
    SELECT MAX(review.id) FROM revisiones_proyectos_finales review WHERE review.proyecto_final_id=pf.id
  )
  WHERE pf.estado='aprobado' AND latest_review.etapa='evaluador' AND latest_review.decision='aprobado'
    AND (d.director_id=? OR ei.evaluador_id=?)
  ORDER BY latest_review.revisada_en DESC,pf.id DESC
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<sql:query var="teacherIdeas" dataSource="jdbc/ProjectsDB">
  SELECT i.codigo,i.titulo,i.estado,i.enviada_en,i.problema,i.descripcion,i.objetivos,
    i.recursos_tecnologias,i.beneficiarios,p.nombre AS programa,a.nombre AS area,
    latest_review.decision AS ultima_decision,latest_review.observaciones AS observaciones_revision,
    latest_review.revisada_en AS revisada_en
  FROM ideas i
  JOIN programas_academicos p ON p.id=i.programa_id
  JOIN areas_tematicas a ON a.id=i.area_id
  LEFT JOIN revisiones_ideas latest_review ON latest_review.id=(
    SELECT MAX(review.id) FROM revisiones_ideas review WHERE review.idea_id=i.id
  )
  WHERE i.proponente_id=? AND i.tipo='institucional'
    AND NOT EXISTS (
      SELECT 1 FROM proyectos_finales completed_pf
      JOIN anteproyectos completed_ap ON completed_ap.id=completed_pf.anteproyecto_id
      WHERE completed_ap.idea_id=i.id AND completed_pf.estado='aprobado'
    )
  ORDER BY i.creada_en DESC,i.id DESC
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<sql:query var="reviewHistory" dataSource="jdbc/ProjectsDB">
  SELECT r.id AS review_id,r.etapa,r.decision,r.observaciones,r.revisada_en,ap.titulo,ap.enlace_drive,
    u.nombre_completo AS estudiante,i.titulo AS idea_titulo,'anteproyecto' AS tipo_entrega
  FROM revisiones_anteproyectos r
  JOIN anteproyectos ap ON ap.id=r.anteproyecto_id
  JOIN usuarios u ON u.id=ap.estudiante_id
  JOIN ideas i ON i.id=ap.idea_id
  WHERE r.director_id=?
  UNION ALL
  SELECT r.id AS review_id,r.etapa,r.decision,r.observaciones,r.revisada_en,pf.titulo,pf.enlace_drive,
    u.nombre_completo AS estudiante,i.titulo AS idea_titulo,'proyecto_final' AS tipo_entrega
  FROM revisiones_proyectos_finales r
  JOIN proyectos_finales pf ON pf.id=r.proyecto_final_id
  JOIN anteproyectos ap ON ap.id=pf.anteproyecto_id
  JOIN usuarios u ON u.id=ap.estudiante_id
  JOIN ideas i ON i.id=ap.idea_id
  WHERE r.revisor_id=?
  ORDER BY revisada_en DESC,review_id DESC
  <sql:param value="${sessionScope.userId}" />
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<c:url var="stylesUrl" value="/assets/css/styles.css?v=20261021a" />
<c:url var="teacherUrl" value="/docente.jsp" />
<c:url var="proposalsUrl" value="/docente.jsp?view=ideas" />
<c:url var="historyUrl" value="/docente.jsp?view=historial" />
<c:url var="logoutUrl" value="/logout.jsp" />
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#f5f7f6">
  <title><c:choose><c:when test="${currentSection eq 'ideas'}">Proponer idea</c:when><c:when test="${currentSection eq 'historial'}">Historial docente</c:when><c:otherwise>Anteproyectos asignados</c:otherwise></c:choose> | Proyectos de grado UTS</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="${stylesUrl}">
</head>
<body>
  <div class="app-shell admin-shell">
    <aside class="sidebar admin-sidebar">
      <a class="brand sidebar-brand" href="${teacherUrl}" aria-label="UTS espacio docente">
        <span class="brand-mark" aria-hidden="true"><span>U</span><span>T</span><span>S</span></span>
        <span class="brand-copy"><strong>UTS</strong><span>Proyectos de grado</span></span>
      </a>
      <div class="sidebar-label">ESPACIO DOCENTE</div>
      <nav class="side-nav" aria-label="Menú docente">
        <a class="nav-link ${currentSection eq 'proyectos' ? 'active' : ''}" href="${teacherUrl}" aria-current="${currentSection eq 'proyectos' ? 'page' : 'false'}"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v16H6.5A2.5 2.5 0 0 0 4 21.5v-16Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M4 17.5A2.5 2.5 0 0 1 6.5 15H20M8 7h8M8 10.5h8" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>Anteproyectos <span class="nav-count"><c:out value="${fn:length(pendingAnteproyectos.rows)}" /></span></a>
        <a class="nav-link ${currentSection eq 'ideas' ? 'active' : ''}" href="${proposalsUrl}" aria-current="${currentSection eq 'ideas' ? 'page' : 'false'}"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 5v14m-7-7h14" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.7"/></svg>Proponer idea</a>
        <a class="nav-link ${currentSection eq 'historial' ? 'active' : ''}" href="${historyUrl}" aria-current="${currentSection eq 'historial' ? 'page' : 'false'}"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M3.5 12a8.5 8.5 0 1 0 2.3-5.8L3.5 8.5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/><path d="M3.5 4.5v4h4m4.5-1v5l3 2" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>Historial</a>
        <a class="nav-link" href="https://www.uts.edu.co/calendario-academico/" target="_blank" rel="noopener noreferrer"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5" stroke="currentColor" stroke-width="1.7"/><path d="M7.5 3.5v3m9-3v3m-13 3h17m-13 4h3m3 0h3m-9 3.5h3" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>Calendario académico <span aria-hidden="true">↗</span></a>
      </nav>
      <div class="sidebar-bottom"><div class="admin-security-card"><span aria-hidden="true">✓</span><strong>Revisión de proyectos</strong><p>Revisa los anteproyectos asignados como director o evaluador.</p></div><div class="sidebar-version">PLATAFORMA DE PROYECTOS <span>v1.0</span></div></div>
    </aside>
    <section class="main-area">
      <header class="topbar">
        <div class="breadcrumb"><span>Docente</span><span class="crumb-slash">/</span><strong><c:choose><c:when test="${currentSection eq 'ideas'}">Proponer idea</c:when><c:when test="${currentSection eq 'historial'}">Historial</c:when><c:otherwise>Anteproyectos</c:otherwise></c:choose></strong></div>
        <div class="topbar-actions"><span class="admin-role-badge">DOCENTE</span><span class="topbar-divider"></span><span class="profile-button"><span class="avatar"><c:out value="${fn:toUpperCase(fn:substring(currentUserName,0,1))}" /></span><span class="profile-info"><strong><c:out value="${currentUserName}" /></strong><small>Docente · Director / Evaluador</small></span></span><a class="logout-link" href="${logoutUrl}">Cerrar sesión</a></div>
      </header>
      <main class="admin-page coordinator-page teacher-page">
        <section class="admin-heading"><div><p class="section-overline"><span></span> <c:choose><c:when test="${currentSection eq 'ideas'}">PROPUESTAS PARA EL BANCO</c:when><c:when test="${currentSection eq 'historial'}">REGISTRO DE ACTIVIDAD</c:when><c:otherwise>REVISIÓN DE PROYECTOS</c:otherwise></c:choose></p><h1><c:choose><c:when test="${currentSection eq 'ideas'}">Proponer idea</c:when><c:when test="${currentSection eq 'historial'}">Historial de decisiones</c:when><c:otherwise>Proyectos asignados</c:otherwise></c:choose></h1><p><c:choose><c:when test="${currentSection eq 'ideas'}">Envía una propuesta al banco de ideas y consulta su estado de aprobación.</c:when><c:when test="${currentSection eq 'historial'}">Consulta las decisiones registradas sobre anteproyectos y proyectos finales.</c:when><c:otherwise>Revisa anteproyectos y proyectos finales según tu asignación como director o evaluador.</c:otherwise></c:choose></p></div><div class="admin-total"><strong><c:choose><c:when test="${currentSection eq 'ideas'}"><c:out value="${fn:length(teacherIdeas.rows)}" /></c:when><c:when test="${currentSection eq 'historial'}"><c:out value="${fn:length(reviewHistory.rows)}" /></c:when><c:otherwise><c:out value="${fn:length(pendingAnteproyectos.rows) + fn:length(pendingFinalProjects.rows)}" /></c:otherwise></c:choose></strong><span><c:choose><c:when test="${currentSection eq 'ideas'}">ideas propuestas</c:when><c:when test="${currentSection eq 'historial'}">decisiones</c:when><c:otherwise>pendientes de revisión</c:otherwise></c:choose></span></div></section>
        <c:if test="${not empty pageError}"><div class="admin-alert admin-alert-error" role="alert"><strong>No se completó la operación.</strong><span><c:out value="${pageError}" /></span></div></c:if>
        <c:if test="${not empty pageNotice}"><div class="admin-alert admin-alert-success" role="status"><strong>Operación completada</strong><span><c:out value="${pageNotice}" /></span></div></c:if>
        <c:if test="${currentSection eq 'proyectos'}">
        <section class="teacher-project-phases" aria-labelledby="teacherProjectPhasesTitle">
          <div class="coordinator-history-heading"><div><p class="section-overline"><span></span> SEGUIMIENTO</p><h2 id="teacherProjectPhasesTitle">Fase actual de los proyectos asignados</h2><p>Consulta el avance de los proyectos en los que participas como director o evaluador.</p></div><span class="admin-list-count"><c:out value="${fn:length(teacherProjectPhases.rows)}" /> proyectos</span></div>
          <c:choose>
            <c:when test="${empty teacherProjectPhases.rows}"><div class="admin-empty-state"><strong>Aún no tienes proyectos en curso.</strong><span>Los proyectos asignados aparecerán aquí cuando un estudiante inicie el proceso.</span></div></c:when>
            <c:otherwise><div class="teacher-project-phase-list"><c:forEach var="project" items="${teacherProjectPhases.rows}">
              <article class="teacher-project-phase-card">
                <div class="teacher-project-phase-heading"><div><span class="coordinator-idea-code"><c:out value="${project.idea_codigo}" /> · <c:out value="${project.rol_revision}" /></span><h3><c:out value="${project.idea_titulo}" /></h3><p><strong>Estudiante:</strong> <c:out value="${project.estudiante}" /><c:if test="${not empty project.integrante}"> · Compañero: <c:out value="${project.integrante}" /></c:if></p></div></div>
                <jsp:include page="/WEB-INF/project-phase-tracker.jsp"><jsp:param name="phase" value="${project.fase_actual}" /><jsp:param name="requestState" value="${project.solicitud_estado}" /></jsp:include>
              </article>
            </c:forEach></div></c:otherwise>
          </c:choose>
        </section>
        <section class="coordinator-history" aria-labelledby="completedTeacherProjectsTitle">
          <div class="coordinator-history-heading"><div><p class="section-overline"><span></span> ARCHIVO</p><h2 id="completedTeacherProjectsTitle">Proyectos finalizados</h2><p>Proyectos aprobados por el evaluador que ya completaron la fase 6.</p></div><span class="admin-list-count"><c:out value="${fn:length(completedTeacherProjects.rows)}" /> finalizados</span></div>
          <c:choose>
            <c:when test="${empty completedTeacherProjects.rows}"><div class="admin-empty-state"><strong>Aún no hay proyectos finalizados asignados.</strong><span>Los proyectos aprobados por evaluación se conservarán aquí.</span></div></c:when>
            <c:otherwise><div class="coordinator-list">
              <c:forEach var="project" items="${completedTeacherProjects.rows}">
                <article class="coordinator-idea-card">
                  <header class="coordinator-idea-heading"><div><span class="coordinator-idea-code"><c:out value="${project.idea_codigo}" /> · <c:out value="${project.rol_revision}" /></span><h2><c:out value="${project.titulo}" /></h2></div><span class="my-idea-status my-idea-status-approved">Finalizado · Aprobado</span></header>
                  <div class="coordinator-idea-meta"><span><strong>Estudiante</strong><c:out value="${project.estudiante}" /><c:if test="${not empty project.integrante}"> · Compañero: <c:out value="${project.integrante}" /></c:if></span><span><strong>Idea</strong><c:out value="${project.idea_titulo}" /></span><span><strong>Programa</strong><c:out value="${project.programa}" /></span><span><strong>Aprobado</strong><c:out value="${project.aprobado_en}" /></span></div>
                  <section class="coordinator-idea-description"><h3>Descripción</h3><p><c:out value="${project.descripcion}" /></p></section>
                  <a class="drive-link" href="<c:out value='${project.enlace_drive}' />" target="_blank" rel="noopener noreferrer">Abrir proyecto final <span aria-hidden="true">↗</span></a>
                </article>
              </c:forEach>
            </div></c:otherwise>
          </c:choose>
        </section>
        <section class="coordinator-list" aria-label="Anteproyectos pendientes">
          <c:choose>
            <c:when test="${empty pendingAnteproyectos.rows}"><div class="admin-empty-state"><strong>No tienes anteproyectos pendientes.</strong><span>Las entregas aparecerán aquí cuando tengas una asignación como director o evaluador.</span></div></c:when>
            <c:otherwise>
              <c:forEach var="anteproyecto" items="${pendingAnteproyectos.rows}">
                <article class="coordinator-idea-card">
                  <header class="coordinator-idea-heading"><div><span class="coordinator-idea-code"><c:out value="${anteproyecto.idea_codigo}" /> · <c:out value="${anteproyecto.idea_titulo}" /></span><h2><c:out value="${anteproyecto.titulo}" /></h2></div><span class="coordinator-pending"><c:choose><c:when test="${anteproyecto.etapa eq 'evaluador'}">TU ROL: EVALUADOR · PENDIENTE DE EVALUACIÓN</c:when><c:otherwise>TU ROL: DIRECTOR · PENDIENTE DE DIRECCIÓN</c:otherwise></c:choose></span></header>
                  <div class="coordinator-idea-meta"><span><strong>Estudiante</strong><c:out value="${anteproyecto.estudiante}" /><c:if test="${not empty anteproyecto.integrante}"> · Compañero: <c:out value="${anteproyecto.integrante}" /></c:if></span><span><strong>Programa</strong><c:out value="${anteproyecto.programa}" /></span><span><strong>Enviado</strong><c:out value="${anteproyecto.enviado_en}" /></span></div>
                  <section class="coordinator-idea-description">
                    <h3>Información completa de la idea escogida</h3>
                    <div class="coordinator-idea-meta"><span><strong>Programa de la idea</strong><c:out value="${anteproyecto.idea_programa}" /></span><span><strong>Área temática</strong><c:out value="${anteproyecto.idea_area}" /></span></div>
                    <h3>Problema o necesidad</h3><p><c:out value="${anteproyecto.idea_problema}" /></p>
                    <h3>Descripción de la idea</h3><p><c:out value="${anteproyecto.idea_descripcion}" /></p>
                    <h3>Objetivos</h3><p><c:out value="${anteproyecto.idea_objetivos}" /></p>
                    <h3>Tecnologías o recursos</h3><p><c:out value="${anteproyecto.idea_recursos}" /></p>
                    <h3>Beneficiarios</h3><p><c:out value="${anteproyecto.idea_beneficiarios}" /></p>
                  </section>
                  <section class="coordinator-idea-description"><h3>Descripción del anteproyecto</h3><p><c:out value="${anteproyecto.descripcion}" /></p></section>
                  <a class="drive-link" href="<c:out value='${anteproyecto.enlace_drive}' />" target="_blank" rel="noopener noreferrer">Abrir anteproyecto en Google Drive <span aria-hidden="true">↗</span></a>
                  <p class="coordinator-assigned-director"><c:choose><c:when test="${anteproyecto.etapa eq 'evaluador'}">Tu revisión como evaluador se realiza después de la aprobación del director.</c:when><c:otherwise>Estás revisando como director. Si apruebas, pasará al evaluador asignado.</c:otherwise></c:choose></p>
                  <form class="coordinator-review-form" action="${teacherUrl}" method="post">
                    <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="action" value="reviewAnteproyecto"><input type="hidden" name="anteproyectoId" value="<c:out value='${anteproyecto.id}' />">
                    <label class="admin-field" for="teacher-observations-${anteproyecto.id}"><span>Observaciones para el estudiante</span><textarea id="teacher-observations-${anteproyecto.id}" name="observations" maxlength="1200" rows="2" placeholder="Registra las correcciones o recomendaciones"></textarea></label>
                    <div class="coordinator-review-actions"><button class="button button-primary" type="submit" name="decision" value="aprobado"><c:choose><c:when test="${anteproyecto.etapa eq 'evaluador'}">Aprobar anteproyecto</c:when><c:otherwise>Aprobar y enviar al evaluador</c:otherwise></c:choose></button><button class="button coordinator-defer-button" type="submit" name="decision" value="aplazado">Aplazar para corrección</button><button class="button coordinator-reject-button" type="submit" name="decision" value="rechazado">Rechazar</button></div>
                  </form>
                </article>
              </c:forEach>
            </c:otherwise>
          </c:choose>
        </section>
        <section class="coordinator-history" aria-labelledby="finalProjectsReviewTitle">
          <div class="coordinator-history-heading"><div><p class="section-overline"><span></span> FASES 5 Y 6</p><h2 id="finalProjectsReviewTitle">Proyectos finales por revisar</h2><p>El director aprueba primero; después el proyecto pasa al evaluador para la decisión final.</p></div><span class="admin-list-count"><c:out value="${fn:length(pendingFinalProjects.rows)}" /> pendientes</span></div>
          <c:choose>
            <c:when test="${empty pendingFinalProjects.rows}"><div class="admin-empty-state"><strong>No tienes proyectos finales pendientes.</strong><span>Cuando un estudiante envíe su proyecto, aparecerá aquí según tu rol de director o evaluador.</span></div></c:when>
            <c:otherwise><div class="coordinator-list">
              <c:forEach var="finalProject" items="${pendingFinalProjects.rows}">
                <article class="coordinator-idea-card">
                  <header class="coordinator-idea-heading"><div><span class="coordinator-idea-code"><c:out value="${finalProject.idea_codigo}" /> · <c:out value="${finalProject.idea_titulo}" /></span><h2><c:out value="${finalProject.titulo}" /></h2></div><span class="coordinator-pending"><c:choose><c:when test="${finalProject.etapa eq 'director'}">FASE 5 · TU ROL: DIRECTOR</c:when><c:otherwise>FASE 6 · TU ROL: EVALUADOR</c:otherwise></c:choose></span></header>
                  <div class="coordinator-idea-meta"><span><strong>Estudiante</strong><c:out value="${finalProject.estudiante}" /><c:if test="${not empty finalProject.integrante}"> · Compañero: <c:out value="${finalProject.integrante}" /></c:if></span><span><strong>Programa</strong><c:out value="${finalProject.programa}" /></span><span><strong>Enviado</strong><c:out value="${finalProject.enviado_en}" /></span></div>
                  <section class="coordinator-idea-description">
                    <h3>Información completa de la idea escogida</h3>
                    <div class="coordinator-idea-meta"><span><strong>Programa de la idea</strong><c:out value="${finalProject.idea_programa}" /></span><span><strong>Área temática</strong><c:out value="${finalProject.idea_area}" /></span></div>
                    <h3>Problema o necesidad</h3><p><c:out value="${finalProject.idea_problema}" /></p>
                    <h3>Descripción de la idea</h3><p><c:out value="${finalProject.idea_descripcion}" /></p>
                    <h3>Objetivos</h3><p><c:out value="${finalProject.idea_objetivos}" /></p>
                    <h3>Tecnologías o recursos</h3><p><c:out value="${finalProject.idea_recursos}" /></p>
                    <h3>Beneficiarios</h3><p><c:out value="${finalProject.idea_beneficiarios}" /></p>
                  </section>
                  <section class="coordinator-idea-description"><h3>Descripción del proyecto</h3><p><c:out value="${finalProject.descripcion}" /></p></section>
                  <a class="drive-link" href="<c:out value='${finalProject.enlace_drive}' />" target="_blank" rel="noopener noreferrer">Abrir proyecto completo en Google Drive <span aria-hidden="true">↗</span></a>
                  <form class="coordinator-review-form" action="${teacherUrl}" method="post">
                    <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="action" value="reviewFinalProject"><input type="hidden" name="finalProjectId" value="<c:out value='${finalProject.id}' />">
                    <label class="admin-field" for="final-project-observations-${finalProject.id}"><span>Observaciones para el estudiante</span><textarea id="final-project-observations-${finalProject.id}" name="observations" maxlength="1200" rows="2" placeholder="Registra las observaciones de tu revisión"></textarea></label>
                    <div class="coordinator-review-actions"><button class="button button-primary" type="submit" name="decision" value="aprobado"><c:choose><c:when test="${finalProject.etapa eq 'director'}">Aprobar y enviar al evaluador</c:when><c:otherwise>Aprobar proyecto final</c:otherwise></c:choose></button><button class="button coordinator-defer-button" type="submit" name="decision" value="aplazado">Aplazar · solicitar correcciones</button><button class="button coordinator-reject-button" type="submit" name="decision" value="rechazado">Rechazar proyecto</button></div>
                  </form>
                </article>
              </c:forEach>
            </div></c:otherwise>
          </c:choose>
        </section>
        </c:if>
        <c:if test="${currentSection eq 'ideas'}">
        <section class="admin-create-card teacher-proposal-card" id="proponer-idea" aria-labelledby="teacherIdeaTitle">
          <div class="admin-card-heading"><span class="admin-card-icon" aria-hidden="true">+</span><div><h2 id="teacherIdeaTitle">Proponer una idea para el banco</h2><p>La coordinación revisará la propuesta antes de publicarla. Si es aprobada, quedarás registrado como su director.</p></div></div>
          <form class="teacher-idea-form" action="${proposalsUrl}" method="post">
            <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="action" value="proposeIdea">
            <label class="admin-field teacher-field-wide"><span>Título de la idea <i>*</i></span><input name="title" maxlength="120" required></label>
            <label class="admin-field"><span>Programa académico <i>*</i></span><select name="programId" required><option value="">Selecciona un programa</option><c:forEach var="program" items="${programRows.rows}"><option value="<c:out value='${program.id}' />"><c:out value="${program.nombre}" /></option></c:forEach></select></label>
            <label class="admin-field"><span>Área temática <i>*</i></span><select name="areaId" required><option value="">Selecciona un área</option><c:forEach var="area" items="${areaRows.rows}"><option value="<c:out value='${area.id}' />"><c:out value="${area.nombre}" /></option></c:forEach></select></label>
            <label class="admin-field teacher-field-wide"><span>Problema o necesidad identificada <i>*</i></span><textarea name="problem" maxlength="1200" rows="3" required></textarea></label>
            <label class="admin-field teacher-field-wide"><span>Descripción de la propuesta <i>*</i></span><textarea name="description" maxlength="1800" rows="4" required></textarea></label>
            <label class="admin-field teacher-field-wide"><span>Tecnologías o recursos <small>(opcional)</small></span><textarea name="resources" maxlength="800" rows="2"></textarea></label>
            <div class="teacher-idea-submit"><button class="button button-primary" type="submit">Enviar idea a coordinación <span aria-hidden="true">→</span></button></div>
          </form>
        </section>

        <section class="teacher-ideas-history" aria-labelledby="teacherIdeasHistoryTitle"><div class="coordinator-history-heading"><div><p class="section-overline"><span></span> PROPUESTAS AL BANCO</p><h2 id="teacherIdeasHistoryTitle">Mis ideas propuestas</h2><p>Ideas enviadas por ti y su estado de aprobación.</p></div><span class="admin-list-count"><c:out value="${fn:length(teacherIdeas.rows)}" /> ideas</span></div>
          <c:choose><c:when test="${empty teacherIdeas.rows}"><div class="admin-empty-state"><strong>Aún no has propuesto ideas.</strong><span>Tus propuestas aparecerán aquí después de enviarlas a coordinación.</span></div></c:when><c:otherwise><div class="teacher-idea-history-list"><c:forEach var="idea" items="${teacherIdeas.rows}"><article class="teacher-idea-history-card"><div class="teacher-idea-history-main"><div class="teacher-idea-history-heading"><div><span class="coordinator-idea-code"><c:out value="${idea.codigo}" /> · <c:out value="${idea.programa}" /> · <c:out value="${idea.area}" /></span><h3><c:out value="${idea.titulo}" /></h3></div><c:choose><c:when test="${idea.estado eq 'aprobada'}"><span class="my-idea-status my-idea-status-approved">Aprobada</span></c:when><c:when test="${idea.estado eq 'rechazada'}"><span class="my-idea-status my-idea-status-rejected">Rechazada</span></c:when><c:otherwise><span class="my-idea-status my-idea-status-pending">Pendiente de coordinación</span></c:otherwise></c:choose></div><details class="teacher-idea-details"><summary>Ver toda la información</summary><div class="teacher-idea-details-content"><section><h4>Problema o necesidad</h4><p><c:out value="${idea.problema}" /></p></section><section><h4>Descripción de la propuesta</h4><p><c:out value="${idea.descripcion}" /></p></section><c:if test="${not empty idea.objetivos}"><section><h4>Objetivos</h4><p><c:out value="${idea.objetivos}" /></p></section></c:if><c:if test="${not empty idea.recursos_tecnologias}"><section><h4>Tecnologías o recursos</h4><p><c:out value="${idea.recursos_tecnologias}" /></p></section></c:if><c:if test="${not empty idea.beneficiarios}"><section><h4>Beneficiarios</h4><p><c:out value="${idea.beneficiarios}" /></p></section></c:if><c:if test="${not empty idea.ultima_decision}"><section class="teacher-idea-review-summary"><h4>Última revisión · <c:out value="${idea.revisada_en}" /></h4><c:if test="${not empty idea.observaciones_revision}"><p><c:out value="${idea.observaciones_revision}" /></p></c:if></section></c:if></div></details></div></article></c:forEach></div></c:otherwise></c:choose>
        </section>
        </c:if>
        <c:if test="${currentSection eq 'historial'}">
        <section class="coordinator-history" id="historial-docente" aria-labelledby="teacherHistoryTitle"><div class="coordinator-history-heading"><div><p class="section-overline"><span></span> HISTORIAL DE REVISIÓN</p><h2 id="teacherHistoryTitle">Decisiones sobre proyectos</h2><p>Registro de tus decisiones como director o evaluador.</p></div><span class="admin-list-count"><c:out value="${fn:length(reviewHistory.rows)}" /> decisiones</span></div>
          <c:choose><c:when test="${empty reviewHistory.rows}"><div class="admin-empty-state"><strong>Aún no has revisado proyectos.</strong><span>Tus decisiones sobre anteproyectos y proyectos finales aparecerán aquí.</span></div></c:when><c:otherwise><div class="coordinator-history-list"><c:forEach var="review" items="${reviewHistory.rows}"><article class="coordinator-history-card"><div class="coordinator-history-card-heading"><div><span class="coordinator-idea-code"><c:out value="${review.estudiante}" /> · <c:out value="${review.idea_titulo}" /> · <c:choose><c:when test="${review.tipo_entrega eq 'proyecto_final'}">Proyecto final</c:when><c:otherwise>Anteproyecto</c:otherwise></c:choose></span><h3><c:out value="${review.titulo}" /></h3></div><c:choose><c:when test="${review.decision eq 'aprobado'}"><span class="my-idea-status my-idea-status-approved">Aprobado</span></c:when><c:when test="${review.decision eq 'aplazado'}"><span class="my-idea-status my-idea-status-changes">Aplazado</span></c:when><c:otherwise><span class="my-idea-status my-idea-status-rejected">Rechazado</span></c:otherwise></c:choose></div><div class="coordinator-history-meta"><span><strong>Etapa</strong><c:choose><c:when test="${review.etapa eq 'evaluador'}">Evaluador</c:when><c:otherwise>Director</c:otherwise></c:choose></span><span><strong>Fecha</strong><c:out value="${review.revisada_en}" /></span><span><a class="drive-link" href="<c:out value='${review.enlace_drive}' />" target="_blank" rel="noopener noreferrer">Ver documento revisado ↗</a></span></div><c:if test="${not empty review.observaciones}"><div class="my-idea-feedback"><strong>Observaciones registradas</strong><p><c:out value="${review.observaciones}" /></p></div></c:if></article></c:forEach></div></c:otherwise></c:choose>
        </section>
        </c:if>
        <footer class="dashboard-footer"><span>Universitaria Tecnológica de Santander</span><span>Espacio de dirección y propuestas docentes.</span></footer>
      </main>
    </section>
  </div>
</body>
</html>

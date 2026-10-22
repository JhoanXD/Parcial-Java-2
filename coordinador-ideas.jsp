<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<c:choose>
  <c:when test="${empty sessionScope.userId}"><c:redirect url="/login.jsp" /></c:when>
  <c:otherwise>
    <sql:query var="activeCoordinator" dataSource="jdbc/ProjectsDB">
      SELECT u.id,u.nombre_completo,r.nombre AS rol
      FROM usuarios u JOIN usuario_roles ur ON ur.usuario_id=u.id JOIN roles r ON r.id=ur.rol_id
      WHERE u.id=? AND u.estado='activo'
      ORDER BY CASE r.nombre WHEN 'administrador' THEN 1 WHEN 'coordinador' THEN 2 ELSE 3 END
      LIMIT 1
      <sql:param value="${sessionScope.userId}" />
    </sql:query>
    <c:choose>
      <c:when test="${empty activeCoordinator.rows}">
        <c:remove var="userId" scope="session" /><c:remove var="userName" scope="session" /><c:remove var="userRole" scope="session" />
        <c:redirect url="/login.jsp" />
      </c:when>
      <c:when test="${activeCoordinator.rows[0].rol eq 'administrador'}"><c:redirect url="/admin-usuarios.jsp" /></c:when>
      <c:when test="${activeCoordinator.rows[0].rol ne 'coordinador'}"><c:redirect url="/index.jsp" /></c:when>
      <c:otherwise><c:set var="currentUserName" value="${activeCoordinator.rows[0].nombre_completo}" /></c:otherwise>
    </c:choose>
  </c:otherwise>
</c:choose>
<c:choose>
  <c:when test="${param.view eq 'banco' or param.view eq 'estudiantes' or param.view eq 'historial' or param.view eq 'finalizados'}"><c:set var="currentSection" value="${param.view}" /></c:when>
  <c:otherwise><c:set var="currentSection" value="docentes" /></c:otherwise>
</c:choose>
<c:if test="${empty sessionScope.csrfToken}">
  <sql:query var="newCsrf" dataSource="jdbc/ProjectsDB">SELECT LOWER(SHA2(CONCAT(UUID(), RAND(), UUID(), NOW(6)), 256)) AS token</sql:query>
  <c:set var="csrfToken" value="${newCsrf.rows[0].token}" scope="session" />
</c:if>
<sql:query var="activeTeachers" dataSource="jdbc/ProjectsDB">
  SELECT u.id,u.nombre_completo
  FROM docentes d JOIN usuarios u ON u.id=d.usuario_id
  JOIN usuario_roles ur ON ur.usuario_id=u.id JOIN roles r ON r.id=ur.rol_id
  WHERE u.estado='activo' AND r.nombre='docente'
  ORDER BY u.nombre_completo
</sql:query>
<c:if test="${pageContext.request.method eq 'POST'}">
  <c:choose>
    <c:when test="${empty sessionScope.csrfToken or empty param.csrfToken or sessionScope.csrfToken ne param.csrfToken}">
      <c:set var="flashError" value="El formulario expiró. Recarga la página e inténtalo de nuevo." scope="session" />
    </c:when>
    <c:when test="${param.action eq 'reviewIdeaRequest'}">
      <c:choose>
        <c:when test="${empty param.requestId or (param.decision ne 'aprobada' and param.decision ne 'rechazada') or fn:length(param.observations) gt 1200 or (param.decision eq 'rechazada' and empty fn:trim(param.observations))}">
          <c:set var="flashError" value="Verifica la solicitud y agrega el motivo si la rechazas." scope="session" />
        </c:when>
        <c:otherwise>
          <c:set var="updatedRequest" value="0" />
          <c:set var="assignedEvaluator" value="0" />
          <c:set var="requestOwnProposal" value="false" />
          <c:catch var="requestReviewFailure">
            <sql:transaction dataSource="jdbc/ProjectsDB">
              <sql:query var="requestForReview">
                SELECT s.id,s.estudiante_id,s.estado,s.pago_verificado,i.id AS idea_id,
                  i.tipo,i.proponente_id,i.estado AS idea_estado,d.director_id
                FROM solicitudes_ideas s
                JOIN ideas i ON i.id=s.idea_id
                LEFT JOIN direcciones_ideas d ON d.idea_id=i.id
                WHERE s.id=? AND (
                  (s.estado='pendiente' AND i.seleccionada_por=s.estudiante_id AND i.seleccionada_hasta IS NULL)
                  OR (s.estado='retirada' AND s.respondida_en IS NULL AND i.tipo='estudiantil'
                    AND i.proponente_id=s.estudiante_id AND i.seleccionada_por IS NULL)
                )
                FOR UPDATE
                <sql:param value="${param.requestId}" />
              </sql:query>
              <c:if test="${not empty requestForReview.rows}">
                <c:set var="requestOwnProposal" value="${requestForReview.rows[0].tipo eq 'estudiantil' and requestForReview.rows[0].proponente_id eq requestForReview.rows[0].estudiante_id and requestForReview.rows[0].idea_estado ne 'aprobada'}" />
                <c:choose>
                  <c:when test="${param.decision eq 'aprobada' and requestOwnProposal}">
                    <sql:update var="assignedEvaluator">
                      INSERT INTO evaluadores_ideas (idea_id,evaluador_id,asignado_por)
                      SELECT i.id,d.usuario_id,?
                      FROM solicitudes_ideas s
                      JOIN ideas i ON i.id=s.idea_id
                      JOIN docentes d ON d.usuario_id=?
                      JOIN usuarios u ON u.id=d.usuario_id AND u.estado='activo'
                      JOIN usuario_roles ur ON ur.usuario_id=u.id
                      JOIN roles r ON r.id=ur.rol_id AND r.nombre='docente'
                      LEFT JOIN direcciones_ideas director ON director.idea_id=i.id
                      WHERE s.id=? AND s.estado IN ('pendiente','retirada') AND s.pago_verificado=0
                        AND (director.director_id IS NULL OR director.director_id<>d.usuario_id)
                      ON DUPLICATE KEY UPDATE evaluador_id=VALUES(evaluador_id),
                        asignado_por=VALUES(asignado_por),asignado_en=CURRENT_TIMESTAMP
                      <sql:param value="${sessionScope.userId}" />
                      <sql:param value="${param.evaluatorId}" />
                      <sql:param value="${param.requestId}" />
                    </sql:update>
                    <c:if test="${assignedEvaluator ge 1}">
                      <sql:update var="updatedRequest">
                        UPDATE solicitudes_ideas
                        SET pago_verificado=1,respuesta=NULLIF(?,''),respondida_por=?,respondida_en=NOW()
                        WHERE id=? AND estado IN ('pendiente','retirada') AND pago_verificado=0
                        <sql:param value="${fn:trim(param.observations)}" />
                        <sql:param value="${sessionScope.userId}" />
                        <sql:param value="${param.requestId}" />
                      </sql:update>
                    </c:if>
                  </c:when>
                  <c:when test="${param.decision eq 'rechazada' and requestOwnProposal and requestForReview.rows[0].estado eq 'retirada'}">
                    <sql:update var="updatedRequest">
                      UPDATE solicitudes_ideas
                      SET respuesta=NULLIF(?,''),respondida_por=?,respondida_en=NOW()
                      WHERE id=? AND estado='retirada' AND pago_verificado=0
                      <sql:param value="${fn:trim(param.observations)}" />
                      <sql:param value="${sessionScope.userId}" />
                      <sql:param value="${param.requestId}" />
                    </sql:update>
                  </c:when>
                  <c:when test="${param.decision eq 'aprobada' and empty param.evaluatorId}">
                    <c:set var="updatedRequest" value="0" />
                  </c:when>
                  <c:when test="${param.decision eq 'aprobada'}">
                    <sql:update var="assignedEvaluator">
                      INSERT INTO evaluadores_ideas (idea_id,evaluador_id,asignado_por)
                      SELECT i.id,d.usuario_id,?
                      FROM ideas i
                      JOIN direcciones_ideas director ON director.idea_id=i.id
                      JOIN docentes d ON d.usuario_id=?
                      JOIN usuarios u ON u.id=d.usuario_id AND u.estado='activo'
                      JOIN usuario_roles ur ON ur.usuario_id=u.id
                      JOIN roles r ON r.id=ur.rol_id AND r.nombre='docente'
                      JOIN solicitudes_ideas s ON s.idea_id=i.id
                      WHERE s.id=? AND s.estado='pendiente'
                        AND i.seleccionada_por=s.estudiante_id
                        AND director.director_id<>d.usuario_id
                      ON DUPLICATE KEY UPDATE evaluador_id=VALUES(evaluador_id),
                        asignado_por=VALUES(asignado_por),asignado_en=CURRENT_TIMESTAMP
                      <sql:param value="${sessionScope.userId}" />
                      <sql:param value="${param.evaluatorId}" />
                      <sql:param value="${param.requestId}" />
                    </sql:update>
                    <c:if test="${assignedEvaluator ge 1}">
                      <sql:update var="updatedRequest">
                        UPDATE solicitudes_ideas
                        SET estado='aprobada',pago_verificado=1,respuesta=NULLIF(?, ''),
                            respondida_por=?,respondida_en=NOW(),corregir_hasta=NULL
                        WHERE id=? AND estado='pendiente'
                        <sql:param value="${fn:trim(param.observations)}" />
                        <sql:param value="${sessionScope.userId}" />
                        <sql:param value="${param.requestId}" />
                      </sql:update>
                    </c:if>
                  </c:when>
                  <c:otherwise>
                    <sql:update var="updatedRequest">
                      UPDATE solicitudes_ideas
                      SET estado=?,pago_verificado=CASE WHEN ?='aprobada' THEN 1 ELSE 0 END,
                          respuesta=NULLIF(?,''),respondida_por=?,respondida_en=NOW(),
                          corregir_hasta=CASE WHEN ?='rechazada' THEN DATE_ADD(NOW(),INTERVAL 3 DAY) ELSE NULL END
                      WHERE id=? AND estado='pendiente'
                      <sql:param value="${param.decision}" />
                      <sql:param value="${param.decision}" />
                      <sql:param value="${fn:trim(param.observations)}" />
                      <sql:param value="${sessionScope.userId}" />
                      <sql:param value="${param.decision}" />
                      <sql:param value="${param.requestId}" />
                    </sql:update>
                  </c:otherwise>
                </c:choose>
                <c:if test="${updatedRequest eq 1 and param.decision eq 'rechazada'}">
                  <sql:update>
                    UPDATE ideas i JOIN solicitudes_ideas s ON s.idea_id=i.id
                    SET i.seleccionada_hasta=s.corregir_hasta
                    WHERE s.id=? AND i.seleccionada_por=s.estudiante_id
                    <sql:param value="${param.requestId}" />
                  </sql:update>
                </c:if>
              </c:if>
            </sql:transaction>
          </c:catch>
          <c:choose>
            <c:when test="${not empty requestReviewFailure}"><c:set var="flashError" value="No se pudo guardar la decisión sobre el comprobante." scope="session" /></c:when>
            <c:when test="${empty requestForReview.rows}"><c:set var="flashError" value="La solicitud ya fue revisada o no conserva la reserva de esta idea." scope="session" /></c:when>
            <c:when test="${param.decision eq 'aprobada' and empty param.evaluatorId}"><c:set var="flashError" value="Selecciona un docente evaluador antes de verificar el pago." scope="session" /></c:when>
            <c:when test="${param.decision eq 'aprobada' and assignedEvaluator lt 1}"><c:set var="flashError" value="El evaluador no es válido, no tiene un perfil docente activo o coincide con el director de la idea." scope="session" /></c:when>
            <c:when test="${updatedRequest ne 1}"><c:set var="flashError" value="La solicitud ya fue revisada o no conserva la reserva de esta idea." scope="session" /></c:when>
            <c:when test="${param.decision eq 'rechazada' and requestOwnProposal and requestForReview.rows[0].estado eq 'retirada'}"><c:set var="flashNotice" value="El comprobante fue rechazado. La propuesta cancelada se conserva sin publicar hasta que su pago sea verificado." scope="session" /></c:when>
            <c:when test="${param.decision eq 'rechazada'}"><c:set var="flashNotice" value="Se solicitó corregir el comprobante. La idea permanecerá reservada durante 3 días." scope="session" /></c:when>
            <c:when test="${requestOwnProposal and requestForReview.rows[0].estado eq 'retirada'}"><c:set var="flashNotice" value="El comprobante quedó verificado y se asignó el evaluador. La propuesta cancelada sigue en revisión y, si se aprueba, quedará disponible en el banco." scope="session" /></c:when>
            <c:when test="${requestOwnProposal}"><c:set var="flashNotice" value="El comprobante quedó verificado y se asignó el evaluador. La propuesta fue enviada a revisión académica." scope="session" /></c:when>
            <c:otherwise><c:set var="flashNotice" value="La idea quedó asignada al estudiante y se registró el evaluador." scope="session" /></c:otherwise>
          </c:choose>
        </c:otherwise>
      </c:choose>
    </c:when>
    <c:when test="${empty param.ideaId or (param.decision ne 'aprobada' and param.decision ne 'rechazada') or fn:length(param.observations) gt 1200}">
      <c:set var="flashError" value="La decisión no es válida. Revisa la propuesta e inténtalo de nuevo." scope="session" />
    </c:when>
    <c:otherwise>
      <c:choose>
        <c:when test="${param.decision eq 'aprobada'}">
          <sql:query var="ideaForDecision" dataSource="jdbc/ProjectsDB">
            SELECT id,tipo,proponente_id FROM ideas WHERE id=? AND estado IN ('pendiente_revision','en_revision')
            <sql:param value="${param.ideaId}" />
          </sql:query>
          <c:if test="${not empty ideaForDecision.rows and ideaForDecision.rows[0].tipo eq 'estudiantil'}">
            <sql:query var="studentProposalEligibility" dataSource="jdbc/ProjectsDB">
              SELECT id,estado FROM solicitudes_ideas
              WHERE idea_id=? AND estudiante_id=? AND estado IN ('pendiente','retirada') AND pago_verificado=1
              <sql:param value="${param.ideaId}" />
              <sql:param value="${ideaForDecision.rows[0].proponente_id}" />
            </sql:query>
          </c:if>
          <c:set var="directorIdForIdea" value="" />
          <c:choose>
            <c:when test="${empty ideaForDecision.rows}">
              <c:set var="flashError" value="Esta propuesta ya fue revisada o no está disponible." scope="session" />
            </c:when>
            <c:when test="${ideaForDecision.rows[0].tipo eq 'estudiantil' and empty studentProposalEligibility.rows}">
              <c:set var="flashError" value="Antes de aprobar esta propuesta, coordinación debe verificar el comprobante de pago." scope="session" />
            </c:when>
            <c:when test="${ideaForDecision.rows[0].tipo eq 'estudiantil' and empty param.directorId}">
              <c:set var="flashError" value="Selecciona un docente director para la idea estudiantil antes de aprobarla." scope="session" />
            </c:when>
            <c:when test="${ideaForDecision.rows[0].tipo eq 'estudiantil' and empty param.evaluatorId}">
              <c:set var="flashError" value="Selecciona un docente evaluador para la idea estudiantil antes de aprobarla." scope="session" />
            </c:when>
            <c:when test="${ideaForDecision.rows[0].tipo eq 'estudiantil' and param.directorId eq param.evaluatorId}">
              <c:set var="flashError" value="El director y el evaluador deben ser docentes diferentes." scope="session" />
            </c:when>
            <c:when test="${ideaForDecision.rows[0].tipo eq 'estudiantil'}">
              <sql:query var="selectedDirector" dataSource="jdbc/ProjectsDB">
                SELECT d.usuario_id FROM docentes d
                JOIN usuarios u ON u.id=d.usuario_id
                JOIN usuario_roles ur ON ur.usuario_id=u.id
                JOIN roles r ON r.id=ur.rol_id
                WHERE d.usuario_id=? AND u.estado='activo' AND r.nombre='docente'
                <sql:param value="${param.directorId}" />
              </sql:query>
              <c:choose>
                <c:when test="${empty selectedDirector.rows}"><c:set var="flashError" value="El docente seleccionado no tiene un perfil activo de docente." scope="session" /></c:when>
                <c:otherwise>
                  <c:set var="directorIdForIdea" value="${selectedDirector.rows[0].usuario_id}" />
                  <sql:query var="selectedEvaluator" dataSource="jdbc/ProjectsDB">
                    SELECT d.usuario_id FROM docentes d
                    JOIN usuarios u ON u.id=d.usuario_id
                    JOIN usuario_roles ur ON ur.usuario_id=u.id
                    JOIN roles r ON r.id=ur.rol_id
                    WHERE d.usuario_id=? AND u.estado='activo' AND r.nombre='docente'
                      AND d.usuario_id<>?
                    <sql:param value="${param.evaluatorId}" />
                    <sql:param value="${directorIdForIdea}" />
                  </sql:query>
                  <c:if test="${empty selectedEvaluator.rows}">
                    <c:set var="flashError" value="El evaluador debe tener un perfil docente activo y ser diferente del director." scope="session" />
                  </c:if>
                </c:otherwise>
              </c:choose>
            </c:when>
            <c:otherwise>
              <sql:query var="teacherIdeaDirector" dataSource="jdbc/ProjectsDB">
                SELECT director_id FROM direcciones_ideas WHERE idea_id=? AND director_id=?
                <sql:param value="${param.ideaId}" />
                <sql:param value="${ideaForDecision.rows[0].proponente_id}" />
              </sql:query>
              <c:if test="${empty teacherIdeaDirector.rows}"><c:set var="flashError" value="No se encontró el director asignado a la propuesta docente." scope="session" /></c:if>
            </c:otherwise>
          </c:choose>
          <c:if test="${empty flashError}">
            <c:catch var="reviewDatabaseFailure">
              <sql:transaction dataSource="jdbc/ProjectsDB">
                <c:set var="updatedIdea" value="0" />
                <c:if test="${ideaForDecision.rows[0].tipo eq 'estudiantil'}">
                  <sql:query var="studentProposalRequest">
                    SELECT id,estado FROM solicitudes_ideas
                    WHERE idea_id=? AND estudiante_id=? AND estado IN ('pendiente','retirada') AND pago_verificado=1
                    FOR UPDATE
                    <sql:param value="${param.ideaId}" />
                    <sql:param value="${ideaForDecision.rows[0].proponente_id}" />
                  </sql:query>
                </c:if>
                <c:if test="${ideaForDecision.rows[0].tipo ne 'estudiantil' or not empty studentProposalRequest.rows}">
                  <sql:update var="updatedIdea">
                    UPDATE ideas SET estado='aprobada',revisada_en=NOW(),aprobada_en=NOW()
                    WHERE id=? AND estado IN ('pendiente_revision','en_revision')
                      AND (tipo<>'estudiantil' OR EXISTS (
                        SELECT 1 FROM solicitudes_ideas s
                        WHERE s.idea_id=ideas.id AND s.estudiante_id=ideas.proponente_id
                          AND s.estado IN ('pendiente','retirada') AND s.pago_verificado=1
                          AND EXISTS (
                            SELECT 1 FROM docentes evaluator
                            JOIN usuarios evaluator_user ON evaluator_user.id=evaluator.usuario_id AND evaluator_user.estado='activo'
                            JOIN usuario_roles evaluator_role ON evaluator_role.usuario_id=evaluator_user.id
                            JOIN roles evaluator_role_name ON evaluator_role_name.id=evaluator_role.rol_id AND evaluator_role_name.nombre='docente'
                            WHERE evaluator.usuario_id=? AND evaluator.usuario_id<>?
                          )
                      ))
                    <sql:param value="${param.ideaId}" />
                    <sql:param value="${param.evaluatorId}" />
                    <sql:param value="${param.directorId}" />
                  </sql:update>
                </c:if>
                <c:if test="${updatedIdea eq 1}">
                  <c:if test="${ideaForDecision.rows[0].tipo eq 'estudiantil'}">
                    <sql:update var="approvedStudentRequest">
                      UPDATE solicitudes_ideas
                      SET estado=CASE WHEN estado='retirada' THEN 'retirada' ELSE 'aprobada' END,
                          respuesta=CASE WHEN estado='retirada' THEN 'Propuesta aprobada y publicada en el banco.' ELSE 'Propuesta aprobada y asignada al estudiante.' END,
                          respondida_por=?,respondida_en=NOW(),corregir_hasta=NULL
                      WHERE idea_id=? AND estudiante_id=? AND estado IN ('pendiente','retirada') AND pago_verificado=1
                      <sql:param value="${sessionScope.userId}" />
                      <sql:param value="${param.ideaId}" />
                      <sql:param value="${ideaForDecision.rows[0].proponente_id}" />
                    </sql:update>
                    <sql:update>
                      INSERT INTO direcciones_ideas (idea_id,director_id,asignado_por)
                      VALUES (?,?,?)
                      ON DUPLICATE KEY UPDATE director_id=VALUES(director_id),asignado_por=VALUES(asignado_por),asignado_en=CURRENT_TIMESTAMP
                      <sql:param value="${param.ideaId}" />
                      <sql:param value="${directorIdForIdea}" />
                      <sql:param value="${sessionScope.userId}" />
                    </sql:update>
                    <sql:update var="assignedEvaluator">
                      INSERT INTO evaluadores_ideas (idea_id,evaluador_id,asignado_por)
                      SELECT i.id,d.usuario_id,?
                      FROM ideas i
                      JOIN docentes d ON d.usuario_id=?
                      JOIN usuarios u ON u.id=d.usuario_id AND u.estado='activo'
                      JOIN usuario_roles ur ON ur.usuario_id=u.id
                      JOIN roles r ON r.id=ur.rol_id AND r.nombre='docente'
                      JOIN direcciones_ideas director ON director.idea_id=i.id
                      WHERE i.id=? AND director.director_id<>d.usuario_id
                      ON DUPLICATE KEY UPDATE evaluador_id=VALUES(evaluador_id),
                        asignado_por=VALUES(asignado_por),asignado_en=CURRENT_TIMESTAMP
                      <sql:param value="${sessionScope.userId}" />
                      <sql:param value="${param.evaluatorId}" />
                      <sql:param value="${param.ideaId}" />
                    </sql:update>
                  </c:if>
                  <sql:update>
                    INSERT INTO revisiones_ideas (idea_id,revisor_id,decision,observaciones)
                    VALUES (?,?,?,NULLIF(?, ''))
                    <sql:param value="${param.ideaId}" />
                    <sql:param value="${sessionScope.userId}" />
                    <sql:param value="${param.decision}" />
                    <sql:param value="${fn:trim(param.observations)}" />
                  </sql:update>
                </c:if>
              </sql:transaction>
            </c:catch>
            <c:choose>
              <c:when test="${not empty reviewDatabaseFailure}"><c:set var="flashError" value="No se pudo guardar la decisión. Inténtalo nuevamente." scope="session" /></c:when>
              <c:when test="${updatedIdea ne 1}"><c:set var="flashError" value="Esta propuesta ya fue revisada o no está disponible." scope="session" /></c:when>
              <c:when test="${ideaForDecision.rows[0].tipo eq 'estudiantil' and assignedEvaluator ne 1}"><c:set var="flashError" value="No se pudo asignar un evaluador distinto del director. La operación debe intentarse de nuevo." scope="session" /></c:when>
              <c:when test="${ideaForDecision.rows[0].tipo eq 'estudiantil' and not empty studentProposalRequest.rows and studentProposalRequest.rows[0].estado eq 'retirada'}"><c:set var="flashNotice" value="La propuesta cancelada fue aprobada y publicada en el banco con director y evaluador asignados." scope="session" /></c:when>
              <c:otherwise><c:set var="flashNotice" value="La idea fue aprobada y vinculada al estudiante. Quedaron asignados el director y un evaluador diferente." scope="session" /></c:otherwise>
            </c:choose>
          </c:if>
        </c:when>
        <c:otherwise>
          <c:catch var="reviewDatabaseFailure">
            <sql:transaction dataSource="jdbc/ProjectsDB">
              <sql:update var="updatedIdea">
                UPDATE ideas SET estado='rechazada',revisada_en=NOW(),aprobada_en=NULL,
                  seleccionada_por=CASE WHEN tipo='estudiantil' THEN NULL ELSE seleccionada_por END,
                  seleccionada_hasta=CASE WHEN tipo='estudiantil' THEN NULL ELSE seleccionada_hasta END
                WHERE id=? AND estado IN ('pendiente_revision','en_revision')
                <sql:param value="${param.ideaId}" />
              </sql:update>
              <c:if test="${updatedIdea eq 1}">
                <sql:update>
                  UPDATE solicitudes_ideas
                  SET estado=CASE WHEN estado='retirada' THEN 'retirada' ELSE 'rechazada' END,
                      respuesta=NULLIF(?, ''),
                      respondida_por=?,respondida_en=NOW(),corregir_hasta=NULL
                  WHERE idea_id=? AND estudiante_id=(SELECT proponente_id FROM ideas WHERE id=?)
                    AND estado IN ('pendiente','retirada')
                  <sql:param value="${fn:trim(param.observations)}" />
                  <sql:param value="${sessionScope.userId}" />
                  <sql:param value="${param.ideaId}" />
                  <sql:param value="${param.ideaId}" />
                </sql:update>
                <sql:update>
                  INSERT INTO revisiones_ideas (idea_id,revisor_id,decision,observaciones)
                  VALUES (?,?,?,NULLIF(?, ''))
                  <sql:param value="${param.ideaId}" />
                  <sql:param value="${sessionScope.userId}" />
                  <sql:param value="${param.decision}" />
                  <sql:param value="${fn:trim(param.observations)}" />
                </sql:update>
              </c:if>
            </sql:transaction>
          </c:catch>
          <c:choose>
            <c:when test="${not empty reviewDatabaseFailure}"><c:set var="flashError" value="No se pudo guardar la decisión. Inténtalo nuevamente." scope="session" /></c:when>
            <c:when test="${updatedIdea ne 1}"><c:set var="flashError" value="Esta propuesta ya fue revisada o no está disponible." scope="session" /></c:when>
            <c:otherwise><c:set var="flashNotice" value="La idea fue rechazada. El proceso del estudiante se cerró y puede solicitar otra idea." scope="session" /></c:otherwise>
          </c:choose>
        </c:otherwise>
      </c:choose>
    </c:otherwise>
  </c:choose>
  <c:redirect url="/coordinador-ideas.jsp?view=${currentSection}" />
</c:if>
<c:if test="${not empty sessionScope.flashNotice}"><c:set var="pageNotice" value="${sessionScope.flashNotice}" /><c:remove var="flashNotice" scope="session" /></c:if>
<c:if test="${not empty sessionScope.flashError}"><c:set var="pageError" value="${sessionScope.flashError}" /><c:remove var="flashError" scope="session" /></c:if>
<sql:query var="pendingBankIdeaRequests" dataSource="jdbc/ProjectsDB">
  SELECT s.id,s.estado,s.comprobante_pago_url,s.mensaje,s.creada_en,s.estudiante_id,i.codigo,i.titulo,
    i.tipo,i.proponente_id,d.director_id,assigned_evaluator.evaluador_id AS evaluador_asignado,partner.nombre_completo AS integrante,
    u.nombre_completo AS estudiante,u.correo,p.nombre AS programa
  FROM solicitudes_ideas s
  JOIN ideas i ON i.id=s.idea_id
  JOIN usuarios u ON u.id=s.estudiante_id
  JOIN estudiantes e ON e.usuario_id=s.estudiante_id
  JOIN programas_academicos p ON p.id=e.programa_id
  LEFT JOIN direcciones_ideas d ON d.idea_id=i.id
  LEFT JOIN evaluadores_ideas assigned_evaluator ON assigned_evaluator.idea_id=i.id
  LEFT JOIN usuarios partner ON partner.id=s.integrante_id
  WHERE s.pago_verificado=0 AND s.estado='pendiente'
    AND i.seleccionada_por=s.estudiante_id AND i.seleccionada_hasta IS NULL
    AND i.proponente_id<>s.estudiante_id
  ORDER BY s.creada_en ASC,s.id ASC
</sql:query>
<sql:query var="pendingStudentProposals" dataSource="jdbc/ProjectsDB">
  SELECT s.id AS solicitud_id,i.id AS idea_id,'pago' AS etapa,s.estado AS estado_solicitud,
    s.comprobante_pago_url,s.mensaje,s.creada_en,i.codigo,i.titulo,i.problema,i.descripcion,i.recursos_tecnologias,
    a.nombre AS area,d.director_id,assigned_evaluator.evaluador_id AS evaluador_asignado,partner.nombre_completo AS integrante,
    u.nombre_completo AS estudiante,u.correo,p.nombre AS programa
  FROM solicitudes_ideas s
  JOIN ideas i ON i.id=s.idea_id
  JOIN usuarios u ON u.id=s.estudiante_id
  JOIN estudiantes e ON e.usuario_id=s.estudiante_id
  JOIN programas_academicos p ON p.id=e.programa_id
  JOIN areas_tematicas a ON a.id=i.area_id
  LEFT JOIN direcciones_ideas d ON d.idea_id=i.id
  LEFT JOIN evaluadores_ideas assigned_evaluator ON assigned_evaluator.idea_id=i.id
  LEFT JOIN usuarios partner ON partner.id=s.integrante_id
  WHERE s.pago_verificado=0 AND i.tipo='estudiantil' AND i.proponente_id=s.estudiante_id
    AND (
      (s.estado='pendiente' AND i.seleccionada_por=s.estudiante_id AND i.seleccionada_hasta IS NULL)
      OR (s.estado='retirada' AND s.respondida_en IS NULL AND i.seleccionada_por IS NULL)
    )
  UNION ALL
  SELECT s.id AS solicitud_id,i.id AS idea_id,'revision' AS etapa,s.estado AS estado_solicitud,
    s.comprobante_pago_url,s.mensaje,s.creada_en,i.codigo,i.titulo,i.problema,i.descripcion,i.recursos_tecnologias,
    a.nombre AS area,d.director_id,assigned_evaluator.evaluador_id AS evaluador_asignado,partner.nombre_completo AS integrante,
    u.nombre_completo AS estudiante,u.correo,p.nombre AS programa
  FROM ideas i
  JOIN solicitudes_ideas s ON s.idea_id=i.id AND s.estudiante_id=i.proponente_id
    AND s.estado IN ('pendiente','retirada') AND s.pago_verificado=1
  JOIN usuarios u ON u.id=s.estudiante_id
  JOIN estudiantes e ON e.usuario_id=s.estudiante_id
  JOIN programas_academicos p ON p.id=i.programa_id
  JOIN areas_tematicas a ON a.id=i.area_id
  LEFT JOIN direcciones_ideas d ON d.idea_id=i.id
  LEFT JOIN evaluadores_ideas assigned_evaluator ON assigned_evaluator.idea_id=i.id
  LEFT JOIN usuarios partner ON partner.id=s.integrante_id
  WHERE i.estado IN ('pendiente_revision','en_revision') AND i.tipo='estudiantil'
  ORDER BY creada_en ASC,solicitud_id ASC
</sql:query>
<sql:query var="pendingTeacherIdeas" dataSource="jdbc/ProjectsDB">
  SELECT i.id,i.codigo,i.titulo,i.problema,i.descripcion,i.recursos_tecnologias,i.creada_en,i.tipo,
    p.nombre AS programa,a.nombre AS area,u.nombre_completo AS proponente,u.correo
  FROM ideas i
  JOIN programas_academicos p ON p.id=i.programa_id
  JOIN areas_tematicas a ON a.id=i.area_id
  JOIN usuarios u ON u.id=i.proponente_id
  WHERE i.estado IN ('pendiente_revision','en_revision') AND i.tipo='institucional'
  ORDER BY i.enviada_en ASC,i.id ASC
</sql:query>
<sql:query var="reviewedIdeas" dataSource="jdbc/ProjectsDB">
  SELECT r.id,r.decision,r.observaciones,r.revisada_en,
    i.codigo,i.titulo,i.tipo,i.estado AS estado_actual,
    u.nombre_completo AS proponente,p.nombre AS programa,a.nombre AS area
  FROM revisiones_ideas r
  JOIN ideas i ON i.id=r.idea_id
  JOIN usuarios u ON u.id=i.proponente_id
  JOIN programas_academicos p ON p.id=i.programa_id
  JOIN areas_tematicas a ON a.id=i.area_id
  WHERE r.revisor_id=? AND r.decision IN ('aprobada','rechazada')
  ORDER BY r.revisada_en DESC,r.id DESC
  <sql:param value="${sessionScope.userId}" />
</sql:query>
<sql:query var="completedProjects" dataSource="jdbc/ProjectsDB">
  SELECT pf.id,pf.titulo,pf.descripcion,pf.enlace_drive,latest_review.revisada_en AS aprobado_en,
    i.codigo AS idea_codigo,i.titulo AS idea_titulo,student.nombre_completo AS estudiante,
    partner.nombre_completo AS integrante,leader.nombre_completo AS director,evaluator.nombre_completo AS evaluador,
    p.nombre AS programa
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
  LEFT JOIN usuarios leader ON leader.id=d.director_id
  LEFT JOIN evaluadores_ideas ei ON ei.idea_id=ap.idea_id
  LEFT JOIN usuarios evaluator ON evaluator.id=ei.evaluador_id
  JOIN revisiones_proyectos_finales latest_review ON latest_review.id=(
    SELECT MAX(review.id) FROM revisiones_proyectos_finales review WHERE review.proyecto_final_id=pf.id
  )
  WHERE pf.estado='aprobado' AND latest_review.etapa='evaluador' AND latest_review.decision='aprobado'
  ORDER BY latest_review.revisada_en DESC,pf.id DESC
</sql:query>
<c:url var="stylesUrl" value="/assets/css/styles.css?v=20261021a" />
<c:url var="reviewUrl" value="/coordinador-ideas.jsp" />
<c:url var="logoutUrl" value="/logout.jsp" />
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#f5f7f6">
  <title><c:choose><c:when test="${currentSection eq 'banco'}">Tomar idea del banco</c:when><c:when test="${currentSection eq 'estudiantes'}">Propuestas propias de estudiantes</c:when><c:when test="${currentSection eq 'historial'}">Historial de decisiones</c:when><c:when test="${currentSection eq 'finalizados'}">Proyectos finalizados</c:when><c:otherwise>Ideas de docentes</c:otherwise></c:choose> | Proyectos de grado UTS</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="${stylesUrl}">
</head>
<body>
  <div class="app-shell admin-shell">
    <aside class="sidebar admin-sidebar">
      <a class="brand sidebar-brand" href="${reviewUrl}" aria-label="UTS Gestión de ideas">
        <span class="brand-mark" aria-hidden="true"><span>U</span><span>T</span><span>S</span></span>
        <span class="brand-copy"><strong>UTS</strong><span>Proyectos de grado</span></span>
      </a>
      <div class="sidebar-label">COORDINACIÓN</div>
      <nav class="side-nav" aria-label="Menú de coordinación">
        <a class="nav-link ${currentSection eq 'docentes' ? 'active' : ''}" href="${reviewUrl}" aria-current="${currentSection eq 'docentes' ? 'page' : 'false'}">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v16H6.5A2.5 2.5 0 0 0 4 21.5v-16Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M4 17.5A2.5 2.5 0 0 1 6.5 15H20M8 7h8M8 10.5h8" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>
          Ideas de docentes <span class="nav-count"><c:out value="${fn:length(pendingTeacherIdeas.rows)}" /></span>
        </a>
        <a class="nav-link ${currentSection eq 'banco' ? 'active' : ''}" href="${reviewUrl}?view=banco" aria-current="${currentSection eq 'banco' ? 'page' : 'false'}">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v16H6.5A2.5 2.5 0 0 0 4 21.5v-16Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M4 17.5A2.5 2.5 0 0 1 6.5 15H20M8 7h8M8 10.5h8" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>
          Tomar idea del banco <span class="nav-count"><c:out value="${fn:length(pendingBankIdeaRequests.rows)}" /></span>
        </a>
        <a class="nav-link ${currentSection eq 'estudiantes' ? 'active' : ''}" href="${reviewUrl}?view=estudiantes" aria-current="${currentSection eq 'estudiantes' ? 'page' : 'false'}">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><circle cx="9" cy="8" r="3.2" stroke="currentColor" stroke-width="1.7"/><path d="M3.5 19.5v-1.2A4.3 4.3 0 0 1 7.8 14h2.4a4.3 4.3 0 0 1 4.3 4.3v1.2M16 5.5a3 3 0 0 1 0 5.8m1 2.7a4.1 4.1 0 0 1 3.5 4v1.5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>
          Propuestas propias de estudiantes <span class="nav-count"><c:out value="${fn:length(pendingStudentProposals.rows)}" /></span>
        </a>
        <a class="nav-link ${currentSection eq 'historial' ? 'active' : ''}" href="${reviewUrl}?view=historial" aria-current="${currentSection eq 'historial' ? 'page' : 'false'}">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M3.5 12a8.5 8.5 0 1 0 2.3-5.8L3.5 8.5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/><path d="M3.5 4.5v4h4m4.5-1v5l3 2" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg>
          Historial de decisiones <span class="nav-count"><c:out value="${fn:length(reviewedIdeas.rows)}" /></span>
        </a>
        <a class="nav-link ${currentSection eq 'finalizados' ? 'active' : ''}" href="${reviewUrl}?view=finalizados" aria-current="${currentSection eq 'finalizados' ? 'page' : 'false'}">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M5 3.5h9l5 5v12H5v-17Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M14 3.5v5h5M8 13h8m-8 3.5h8" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>
          Proyectos finalizados <span class="nav-count"><c:out value="${fn:length(completedProjects.rows)}" /></span>
        </a>
        <a class="nav-link" href="https://www.uts.edu.co/calendario-academico/" target="_blank" rel="noopener noreferrer"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5" stroke="currentColor" stroke-width="1.7"/><path d="M7.5 3.5v3m9-3v3m-13 3h17m-13 4h3m3 0h3m-9 3.5h3" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>Calendario académico <span aria-hidden="true">↗</span></a>
      </nav>
      <div class="sidebar-bottom">
        <div class="admin-security-card"><span aria-hidden="true">✓</span><strong>Gestión académica</strong><p>Revisa las propuestas docentes y las solicitudes de los estudiantes.</p></div>
        <div class="sidebar-version">PLATAFORMA DE PROYECTOS <span>v1.0</span></div>
      </div>
    </aside>
    <section class="main-area">
      <header class="topbar">
        <div class="breadcrumb"><span>Coordinación</span><span class="crumb-slash">/</span><strong><c:choose><c:when test="${currentSection eq 'banco'}">Tomar idea del banco</c:when><c:when test="${currentSection eq 'estudiantes'}">Propuestas propias de estudiantes</c:when><c:when test="${currentSection eq 'historial'}">Historial de decisiones</c:when><c:when test="${currentSection eq 'finalizados'}">Proyectos finalizados</c:when><c:otherwise>Ideas de docentes</c:otherwise></c:choose></strong></div>
        <div class="topbar-actions">
          <span class="admin-role-badge">COORDINADOR</span><span class="topbar-divider"></span>
          <span class="profile-button"><span class="avatar"><c:out value="${fn:toUpperCase(fn:substring(currentUserName,0,1))}" /></span><span class="profile-info"><strong><c:out value="${currentUserName}" /></strong><small>Coordinador</small></span></span>
          <a class="logout-link" href="${logoutUrl}">Cerrar sesión</a>
        </div>
      </header>
      <main class="admin-page coordinator-page">
        <section class="admin-heading">
          <div><p class="section-overline"><span></span> EVALUACIÓN ACADÉMICA</p><h1><c:choose><c:when test="${currentSection eq 'banco'}">Tomar idea del banco</c:when><c:when test="${currentSection eq 'estudiantes'}">Propuestas propias de estudiantes</c:when><c:when test="${currentSection eq 'historial'}">Historial de decisiones</c:when><c:when test="${currentSection eq 'finalizados'}">Proyectos finalizados</c:when><c:otherwise>Ideas de docentes</c:otherwise></c:choose></h1><p><c:choose><c:when test="${currentSection eq 'banco'}">Revisa solicitudes de estudiantes para elegir una idea aprobada del banco.</c:when><c:when test="${currentSection eq 'estudiantes'}">Verifica pagos y revisa las propuestas propias enviadas por estudiantes.</c:when><c:when test="${currentSection eq 'historial'}">Consulta las decisiones de aprobación y rechazo que has registrado.</c:when><c:when test="${currentSection eq 'finalizados'}">Consulta los proyectos cuyo evaluador aprobó la fase final.</c:when><c:otherwise>Revisa y decide sobre las ideas propuestas por docentes para el banco académico.</c:otherwise></c:choose></p></div>
          <div class="admin-total"><strong><c:choose><c:when test="${currentSection eq 'banco'}"><c:out value="${fn:length(pendingBankIdeaRequests.rows)}" /></c:when><c:when test="${currentSection eq 'estudiantes'}"><c:out value="${fn:length(pendingStudentProposals.rows)}" /></c:when><c:when test="${currentSection eq 'historial'}"><c:out value="${fn:length(reviewedIdeas.rows)}" /></c:when><c:when test="${currentSection eq 'finalizados'}"><c:out value="${fn:length(completedProjects.rows)}" /></c:when><c:otherwise><c:out value="${fn:length(pendingTeacherIdeas.rows)}" /></c:otherwise></c:choose></strong><span><c:choose><c:when test="${currentSection eq 'historial'}">decisiones</c:when><c:when test="${currentSection eq 'finalizados'}">proyectos finalizados</c:when><c:otherwise>pendientes</c:otherwise></c:choose></span></div>
        </section>
        <c:if test="${not empty pageError}"><div class="admin-alert admin-alert-error" role="alert"><strong>No se completó la operación.</strong><span><c:out value="${pageError}" /></span></div></c:if>
        <c:if test="${not empty pageNotice}"><div class="admin-alert admin-alert-success" role="status"><strong>Decisión registrada</strong><span><c:out value="${pageNotice}" /></span></div></c:if>
        <c:if test="${currentSection eq 'docentes'}">
        <section class="coordinator-history" id="propuestas-docentes" aria-labelledby="teacherIdeasTitle">
          <div class="coordinator-history-heading"><div><p class="section-overline"><span></span> PROPUESTAS PARA EL BANCO</p><h2 id="teacherIdeasTitle">Ideas propuestas por docentes</h2><p>Revisa las iniciativas de docentes antes de agregarlas al banco de ideas.</p></div><span class="admin-list-count"><c:out value="${fn:length(pendingTeacherIdeas.rows)}" /> pendientes</span></div>
          <c:choose>
            <c:when test="${empty pendingTeacherIdeas.rows}"><div class="admin-empty-state"><strong>No hay propuestas docentes pendientes.</strong><span>Las nuevas ideas para el banco aparecerán aquí.</span></div></c:when>
            <c:otherwise><div class="coordinator-list">
              <c:forEach var="idea" items="${pendingTeacherIdeas.rows}">
                <article class="coordinator-idea-card">
                  <header class="coordinator-idea-heading"><div><span class="coordinator-idea-code"><c:out value="${idea.codigo}" /></span><h2><c:out value="${idea.titulo}" /></h2></div><span class="coordinator-pending">PROPUESTA DOCENTE</span></header>
                  <div class="coordinator-idea-meta"><span><strong>Docente proponente</strong><c:out value="${idea.proponente}" /></span><span><strong>Programa</strong><c:out value="${idea.programa}" /></span><span><strong>Área</strong><c:out value="${idea.area}" /></span><span><strong>Correo</strong><c:out value="${idea.correo}" /></span></div>
                  <section class="coordinator-idea-description"><h3>Problema o necesidad</h3><p><c:out value="${idea.problema}" /></p></section>
                  <section class="coordinator-idea-description"><h3>Descripción de la propuesta</h3><p><c:out value="${idea.descripcion}" /></p></section>
                  <c:if test="${not empty idea.recursos_tecnologias}"><section class="coordinator-idea-description"><h3>Tecnologías o recursos</h3><p><c:out value="${idea.recursos_tecnologias}" /></p></section></c:if>
                  <form class="coordinator-review-form" action="${reviewUrl}?view=docentes" method="post">
                    <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="ideaId" value="<c:out value='${idea.id}' />">
                    <p class="coordinator-assigned-director">El docente proponente quedará registrado como director al aprobar la idea.</p>
                    <label class="admin-field" for="teacher-observations-${idea.id}"><span>Observaciones <small>(opcional)</small></span><textarea id="teacher-observations-${idea.id}" name="observations" maxlength="1200" rows="2" placeholder="Añade una observación para dejar constancia de tu decisión"></textarea></label>
                    <div class="coordinator-review-actions"><button class="button button-primary" type="submit" name="decision" value="aprobada">Agregar al banco</button><button class="button coordinator-reject-button" type="submit" name="decision" value="rechazada" formnovalidate>Rechazar propuesta</button></div>
                  </form>
                </article>
              </c:forEach>
            </div></c:otherwise>
          </c:choose>
        </section>
        </c:if>
        <c:if test="${currentSection eq 'banco'}">
        <section class="coordinator-history" id="solicitudes-estudiantes" aria-labelledby="bankRequestsTitle">
          <div class="coordinator-history-heading"><div><p class="section-overline"><span></span> SELECCIÓN DE PROYECTO</p><h2 id="bankRequestsTitle">Estudiantes que solicitan una idea del banco</h2><p>Verifica el comprobante y, al aprobar, asigna un docente evaluador. Si rechazas, explica el motivo para que el estudiante pueda corregirlo durante 3 días.</p></div><span class="admin-list-count"><c:out value="${fn:length(pendingBankIdeaRequests.rows)}" /> pendientes</span></div>
          <c:choose>
            <c:when test="${empty pendingBankIdeaRequests.rows}"><div class="admin-empty-state"><strong>No hay solicitudes para tomar ideas.</strong><span>Las solicitudes de ideas existentes del banco aparecerán aquí.</span></div></c:when>
            <c:otherwise><div class="coordinator-list">
              <c:forEach var="request" items="${pendingBankIdeaRequests.rows}">
                <article class="coordinator-idea-card">
                  <header class="coordinator-idea-heading"><div><span class="coordinator-idea-code"><c:out value="${request.codigo}" /> · <c:out value="${request.programa}" /></span><h2><c:out value="${request.titulo}" /></h2></div><span class="coordinator-pending">SOLICITUD DE ESTUDIANTE</span></header>
                  <div class="coordinator-idea-meta"><span><strong>Estudiante</strong><c:out value="${request.estudiante}" /></span><span><strong>Correo</strong><c:out value="${request.correo}" /></span><span><strong>Solicitada</strong><c:out value="${request.creada_en}" /></span><c:if test="${not empty request.integrante}"><span><strong>Compañero de proyecto</strong><c:out value="${request.integrante}" /></span></c:if></div>
                  <c:if test="${not empty request.mensaje}"><section class="coordinator-idea-description"><h3>Mensaje del estudiante</h3><p><c:out value="${request.mensaje}" /></p></section></c:if>
                  <a class="drive-link" href="<c:out value='${request.comprobante_pago_url}' />" target="_blank" rel="noopener noreferrer">Abrir comprobante de pago <span aria-hidden="true">↗</span></a>
                  <form class="coordinator-review-form" action="${reviewUrl}?view=banco" method="post">
                    <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="action" value="reviewIdeaRequest"><input type="hidden" name="requestId" value="<c:out value='${request.id}' />">
                    <label class="admin-field coordinator-director-field" for="bank-request-evaluator-${request.id}"><span>Docente evaluador <i>* al aprobar</i></span><select id="bank-request-evaluator-${request.id}" name="evaluatorId" required><option value="">Selecciona un evaluador</option><c:forEach var="teacher" items="${activeTeachers.rows}"><c:if test="${teacher.id ne request.director_id}"><option value="<c:out value='${teacher.id}' />"><c:if test="${teacher.id eq request.evaluador_asignado}">selected</c:if><c:out value="${teacher.nombre_completo}" /></option></c:if></c:forEach></select><small>El evaluador no puede ser el director de la idea.</small></label>
                    <label class="admin-field" for="bank-request-observations-${request.id}"><span>Respuesta / motivo <i>* al rechazar</i></span><textarea id="bank-request-observations-${request.id}" name="observations" maxlength="1200" rows="3" placeholder="Si rechazas, indica qué debe corregir el estudiante"></textarea></label>
                    <div class="coordinator-review-actions"><button class="button button-primary" type="submit" name="decision" value="aprobada">Aprobar y asignar evaluador</button><button class="button coordinator-reject-button" type="submit" name="decision" value="rechazada" formnovalidate>Rechazar y pedir corrección</button></div>
                  </form>
                </article>
              </c:forEach>
            </div></c:otherwise>
          </c:choose>
        </section>
        </c:if>
        <c:if test="${currentSection eq 'estudiantes'}">
        <section class="coordinator-history" id="propuestas-estudiantes" aria-labelledby="studentIdeasTitle">
          <div class="coordinator-history-heading"><div><p class="section-overline"><span></span> PROPUESTAS ESTUDIANTILES</p><h2 id="studentIdeasTitle">Ideas propias de estudiantes</h2><p>El pago y la revisión académica se gestionan aquí; cada tarjeta indica el paso pendiente.</p></div><span class="admin-list-count"><c:out value="${fn:length(pendingStudentProposals.rows)}" /> pendientes</span></div>
          <c:choose>
            <c:when test="${empty pendingStudentProposals.rows}"><div class="admin-empty-state"><strong>No hay propuestas estudiantiles pendientes.</strong><span>Cuando un estudiante envíe una idea propia, aparecerá aquí.</span></div></c:when>
            <c:otherwise><div class="coordinator-list">
              <c:forEach var="proposal" items="${pendingStudentProposals.rows}">
                <article class="coordinator-idea-card">
                  <header class="coordinator-idea-heading"><div><span class="coordinator-idea-code"><c:out value="${proposal.codigo}" /> · <c:out value="${proposal.programa}" /></span><h2><c:out value="${proposal.titulo}" /></h2></div><span class="coordinator-pending"><c:choose><c:when test="${proposal.estado_solicitud eq 'retirada' and proposal.etapa eq 'pago'}">CANCELADA · REVISAR PAGO</c:when><c:when test="${proposal.estado_solicitud eq 'retirada'}">CANCELADA · REVISAR IDEA</c:when><c:when test="${proposal.etapa eq 'pago'}">PAGO PENDIENTE</c:when><c:otherwise>LISTA PARA REVISIÓN</c:otherwise></c:choose></span></header>
                  <div class="coordinator-idea-meta"><span><strong>Estudiante proponente</strong><c:out value="${proposal.estudiante}" /></span><span><strong>Correo</strong><c:out value="${proposal.correo}" /></span><span><strong>Programa</strong><c:out value="${proposal.programa}" /></span><span><strong>Área</strong><c:out value="${proposal.area}" /></span><c:if test="${not empty proposal.integrante}"><span><strong>Compañero de proyecto</strong><c:out value="${proposal.integrante}" /></span></c:if></div>
                  <c:if test="${proposal.estado_solicitud eq 'retirada'}"><p class="request-reservation-note">El estudiante canceló. Si la propuesta se aprueba, quedará disponible en el banco y no se asignará a quien la propuso.</p></c:if>
                  <section class="coordinator-idea-description"><h3>Problema o necesidad</h3><p><c:out value="${proposal.problema}" /></p></section>
                  <section class="coordinator-idea-description"><h3>Descripción de la propuesta</h3><p><c:out value="${proposal.descripcion}" /></p></section>
                  <c:if test="${not empty proposal.recursos_tecnologias}"><section class="coordinator-idea-description"><h3>Tecnologías o recursos</h3><p><c:out value="${proposal.recursos_tecnologias}" /></p></section></c:if>
                  <c:if test="${not empty proposal.mensaje}"><section class="coordinator-idea-description"><h3>Mensaje del estudiante</h3><p><c:out value="${proposal.mensaje}" /></p></section></c:if>
                  <c:if test="${not empty proposal.comprobante_pago_url}"><a class="drive-link" href="<c:out value='${proposal.comprobante_pago_url}' />" target="_blank" rel="noopener noreferrer"><c:choose><c:when test="${proposal.etapa eq 'pago'}">Abrir comprobante de pago</c:when><c:otherwise>Comprobante de pago verificado</c:otherwise></c:choose> <span aria-hidden="true">↗</span></a></c:if>
                  <c:choose>
                    <c:when test="${proposal.etapa eq 'pago'}">
                      <form class="coordinator-review-form" action="${reviewUrl}?view=estudiantes" method="post">
                        <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="action" value="reviewIdeaRequest"><input type="hidden" name="requestId" value="<c:out value='${proposal.solicitud_id}' />">
                        <label class="admin-field coordinator-director-field" for="proposal-evaluator-${proposal.solicitud_id}"><span>Docente evaluador <i>* al verificar</i></span><select id="proposal-evaluator-${proposal.solicitud_id}" name="evaluatorId" required><option value="">Selecciona un evaluador</option><c:forEach var="teacher" items="${activeTeachers.rows}"><c:if test="${teacher.id ne proposal.director_id}"><option value="<c:out value='${teacher.id}' />"><c:if test="${teacher.id eq proposal.evaluador_asignado}">selected</c:if><c:out value="${teacher.nombre_completo}" /></option></c:if></c:forEach></select><small>Al verificar el pago, la propuesta pasará a revisión académica.</small></label>
                        <label class="admin-field" for="proposal-payment-observations-${proposal.solicitud_id}"><span>Respuesta / motivo <i>* al rechazar</i></span><textarea id="proposal-payment-observations-${proposal.solicitud_id}" name="observations" maxlength="1200" rows="3" placeholder="Si rechazas, indica qué debe corregir el estudiante"></textarea></label>
                        <div class="coordinator-review-actions"><button class="button button-primary" type="submit" name="decision" value="aprobada">Verificar pago</button><button class="button coordinator-reject-button" type="submit" name="decision" value="rechazada" formnovalidate><c:choose><c:when test="${proposal.estado_solicitud eq 'retirada'}">Rechazar comprobante</c:when><c:otherwise>Rechazar y pedir corrección</c:otherwise></c:choose></button></div>
                      </form>
                    </c:when>
                    <c:otherwise>
                      <form class="coordinator-review-form" action="${reviewUrl}?view=estudiantes" method="post">
                        <input type="hidden" name="csrfToken" value="<c:out value='${sessionScope.csrfToken}' />"><input type="hidden" name="ideaId" value="<c:out value='${proposal.idea_id}' />">
                        <label class="admin-field coordinator-director-field" for="director-${proposal.idea_id}"><span>Director del proyecto <i>*</i></span><select id="director-${proposal.idea_id}" name="directorId" required><option value="">Selecciona un docente director</option><c:forEach var="teacher" items="${activeTeachers.rows}"><option value="<c:out value='${teacher.id}' />"><c:out value="${teacher.nombre_completo}" /></option></c:forEach></select></label>
                        <label class="admin-field coordinator-director-field" for="evaluator-${proposal.idea_id}"><span>Docente evaluador <i>*</i></span><select id="evaluator-${proposal.idea_id}" name="evaluatorId" required><option value="">Selecciona un docente evaluador</option><c:forEach var="teacher" items="${activeTeachers.rows}"><option value="<c:out value='${teacher.id}' />"><c:if test="${teacher.id eq proposal.evaluador_asignado}">selected</c:if><c:out value="${teacher.nombre_completo}" /></option></c:forEach></select><small>Debe ser una persona diferente del director.</small></label>
                        <label class="admin-field" for="student-observations-${proposal.idea_id}"><span>Observaciones <small>(opcional)</small></span><textarea id="student-observations-${proposal.idea_id}" name="observations" maxlength="1200" rows="2" placeholder="Añade una observación para dejar constancia de tu decisión"></textarea></label>
                        <div class="coordinator-review-actions"><button class="button button-primary" type="submit" name="decision" value="aprobada">Aprobar propuesta</button><button class="button coordinator-reject-button" type="submit" name="decision" value="rechazada" formnovalidate>Rechazar propuesta</button></div>
                      </form>
                    </c:otherwise>
                  </c:choose>
                </article>
              </c:forEach>
            </div></c:otherwise>
          </c:choose>
        </section>
        </c:if>
        <c:if test="${currentSection eq 'finalizados'}">
        <section class="coordinator-history" id="proyectos-finalizados" aria-labelledby="completedProjectsTitle">
          <div class="coordinator-history-heading"><div><p class="section-overline"><span></span> ARCHIVO ACADÉMICO</p><h2 id="completedProjectsTitle">Proyectos finalizados</h2><p>Proyectos cuyo evaluador aprobó la fase 6.</p></div><span class="admin-list-count"><c:out value="${fn:length(completedProjects.rows)}" /> finalizados</span></div>
          <c:choose>
            <c:when test="${empty completedProjects.rows}"><div class="admin-empty-state"><strong>Aún no hay proyectos finalizados.</strong><span>Los proyectos aprobados por evaluación se conservarán aquí.</span></div></c:when>
            <c:otherwise><div class="coordinator-list">
              <c:forEach var="project" items="${completedProjects.rows}">
                <article class="coordinator-idea-card">
                  <header class="coordinator-idea-heading"><div><span class="coordinator-idea-code"><c:out value="${project.idea_codigo}" /> · <c:out value="${project.idea_titulo}" /></span><h2><c:out value="${project.titulo}" /></h2></div><span class="my-idea-status my-idea-status-approved">Finalizado · Aprobado</span></header>
                  <div class="coordinator-idea-meta"><span><strong>Estudiante</strong><c:out value="${project.estudiante}" /><c:if test="${not empty project.integrante}"> · <c:out value="${project.integrante}" /></c:if></span><span><strong>Director</strong><c:out value="${project.director}" /></span><span><strong>Evaluador</strong><c:out value="${project.evaluador}" /></span><span><strong>Programa</strong><c:out value="${project.programa}" /></span><span><strong>Aprobado</strong><c:out value="${project.aprobado_en}" /></span></div>
                  <section class="coordinator-idea-description"><h3>Descripción</h3><p><c:out value="${project.descripcion}" /></p></section>
                  <a class="drive-link" href="<c:out value='${project.enlace_drive}' />" target="_blank" rel="noopener noreferrer">Abrir proyecto final <span aria-hidden="true">↗</span></a>
                </article>
              </c:forEach>
            </div></c:otherwise>
          </c:choose>
        </section>
        </c:if>
        <c:if test="${currentSection eq 'historial'}">
        <section class="coordinator-history" id="historial" aria-labelledby="coordinatorHistoryTitle">
          <div class="coordinator-history-heading">
            <div><p class="section-overline"><span></span> REGISTRO DE ACTIVIDAD</p><h2 id="coordinatorHistoryTitle">Ideas que revisé</h2><p>Historial de las decisiones de aprobación y rechazo que has registrado.</p></div>
            <span class="admin-list-count"><c:out value="${fn:length(reviewedIdeas.rows)}" /> decisiones</span>
          </div>
          <c:choose>
            <c:when test="${empty reviewedIdeas.rows}">
              <div class="admin-empty-state"><strong>Aún no has tomado decisiones.</strong><span>Las ideas que apruebes o rechaces aparecerán aquí con su fecha y observaciones.</span></div>
            </c:when>
            <c:otherwise>
              <div class="coordinator-history-list">
                <c:forEach var="review" items="${reviewedIdeas.rows}">
                  <article class="coordinator-history-card">
                    <div class="coordinator-history-card-heading">
                      <div><span class="coordinator-idea-code"><c:out value="${review.codigo}" /></span><h3><c:out value="${review.titulo}" /></h3></div>
                      <c:choose>
                        <c:when test="${review.decision eq 'aprobada'}"><span class="my-idea-status my-idea-status-approved">Aprobada</span></c:when>
                        <c:otherwise><span class="my-idea-status my-idea-status-rejected">Rechazada</span></c:otherwise>
                      </c:choose>
                    </div>
                    <div class="coordinator-history-meta"><span><strong><c:choose><c:when test="${review.tipo eq 'institucional'}">Docente proponente</c:when><c:otherwise>Estudiante proponente</c:otherwise></c:choose></strong><c:out value="${review.proponente}" /></span><span><strong>Tipo de gestión</strong><c:choose><c:when test="${review.tipo eq 'institucional'}">Propuesta para el banco</c:when><c:otherwise>Idea propia de estudiante</c:otherwise></c:choose></span><span><strong>Programa</strong><c:out value="${review.programa}" /></span><span><strong>Fecha de decisión</strong><c:out value="${review.revisada_en}" /></span></div>
                    <c:if test="${not empty review.observaciones}"><div class="my-idea-feedback"><strong>Observaciones registradas</strong><p><c:out value="${review.observaciones}" /></p></div></c:if>
                  </article>
                </c:forEach>
              </div>
            </c:otherwise>
          </c:choose>
        </section>
        </c:if>
        <footer class="dashboard-footer"><span>Universitaria Tecnológica de Santander</span><span>Las decisiones de revisión quedan registradas en el historial académico.</span></footer>
      </main>
    </section>
  </div>
</body>
</html>

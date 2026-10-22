<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="currentPhase" value="${param.phase}" />
<section class="project-phase-tracker" aria-label="Fase ${currentPhase} de 6 del proyecto">
  <ol class="project-phase-steps">
    <c:forEach var="phaseIndex" begin="1" end="6">
      <li class="project-phase-step<c:choose><c:when test='${phaseIndex lt currentPhase}'> project-phase-complete</c:when><c:when test='${phaseIndex eq currentPhase}'> project-phase-current</c:when><c:otherwise> project-phase-upcoming</c:otherwise></c:choose>"<c:if test="${phaseIndex eq currentPhase}"> aria-current="step"</c:if>>
        <span class="project-phase-number"><c:out value="${phaseIndex}" /></span>
        <span class="project-phase-label">Fase <c:out value="${phaseIndex}" /></span>
      </li>
    </c:forEach>
  </ol>
</section>

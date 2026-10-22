<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:remove var="userId" scope="session" />
<c:remove var="userName" scope="session" />
<c:remove var="userRole" scope="session" />
<c:remove var="csrfToken" scope="session" />
<c:redirect url="/login.jsp" />

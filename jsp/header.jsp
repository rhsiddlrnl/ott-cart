<%@ page pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="ko">
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>OTT Cart</title>
	<link rel="stylesheet" href="style.css">
</head>
<body>
	<header class="topbar">
		<div class="wrap bar">
			<a class="logo" href="search.jsp"><span class="logo-mark">▶</span> OTT Cart</a>
			<nav>
				<a href="search.jsp"  class="<%= "search".equals( navActive )  ? "on" : "" %>">작품 검색</a>
				<a href="cart.jsp"    class="<%= "cart".equals( navActive )    ? "on" : "" %>">내 카트</a>
				<a href="ranking.jsp" class="<%= "ranking".equals( navActive ) ? "on" : "" %>">인기 랭킹</a>
			</nav>
		</div>
	</header>
	<main class="wrap">
<% if ( flash != null ) { %>
		<div class="flash"><%= h( flash ) %></div>
<% } %>

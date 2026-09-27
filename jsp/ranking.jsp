<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" import="java.util.*" %>
<%@ include file="SQLconstants.jsp" %>
<%@ include file="util.jsp" %>
<%@ include file="log.jsp" %>
<%
	// game 예제의 랭킹(selectSQL.jsp)을 "많은 회원이 카트에 담은 작품" 랭킹으로 변경
	request.setCharacterEncoding( "UTF-8" );
	String type = request.getParameter( "type" );
	// 예제 : title 전달인자를 그대로 SQL 에 붙임 → 허용된 값(all, movie, tv)만 사용
	if ( !"movie".equals( type ) && !"tv".equals( type ) ) type = "all";
	String flash = takeFlash( session );
	String error = null;

	List<String[]> rows = new ArrayList<>();

	// 예제 : for ( rank = 1; ... ; rank++ ) → 점수가 같아도 순위가 달라짐
	// 수정 : RANK() 윈도 함수로 동점이면 같은 순위, LIMIT 10 으로 TOP 10
	String query = "SELECT RANK() OVER (ORDER BY COUNT(*) DESC) AS rnk, "
		+ "t.title_id, t.name, t.title_type, t.release_year, COUNT(*) AS cnt, "
		+ "EXISTS (SELECT 1 FROM cart_items m WHERE m.user_id = ? AND m.title_id = t.title_id) AS in_cart "
		+ "FROM cart_items c JOIN titles t ON t.title_id = c.title_id "
		+ "WHERE ( ? = 'all' OR t.title_type = ? ) "
		+ "GROUP BY t.title_id, t.name, t.title_type, t.release_year "
		+ "ORDER BY cnt DESC, t.name "
		+ "LIMIT 10";

	try ( Connection con = getConnection();
	      PreparedStatement ps = con.prepareStatement( query ) )
	{
		ps.setInt( 1, DEMO_USER_ID );
		ps.setString( 2, type );
		ps.setString( 3, type );
		try ( ResultSet rs = ps.executeQuery() )
		{
			while ( rs.next() )
				rows.add( new String[] {
					rs.getString( "rnk" ), rs.getString( "title_id" ), rs.getString( "name" ),
					rs.getString( "title_type" ), rs.getString( "release_year" ), rs.getString( "cnt" ), rs.getString( "in_cart" ) } );
		}
	}
	catch ( Exception e )
	{
		error = e.getMessage();
	}

	// 로그 데이터 추출
	writeLog( "ranking_view", ( error != null ) ? "ERROR " + error : "type=" + type + ", rows=" + rows.size(), request, session );

	String navActive = "ranking";
%>
<%@ include file="header.jsp" %>
		<h1>인기 랭킹 <small>카트에 많이 담긴 작품 TOP 10</small></h1>
		<div class="tabs">
			<a href="ranking.jsp"            class="<%= "all".equals( type )   ? "on" : "" %>">전체</a>
			<a href="ranking.jsp?type=movie" class="<%= "movie".equals( type ) ? "on" : "" %>">영화</a>
			<a href="ranking.jsp?type=tv"    class="<%= "tv".equals( type )    ? "on" : "" %>">드라마</a>
		</div>

<% if ( error != null ) { %>
		<p class="error">DB 오류 : <%= h( error ) %></p>
<% } %>
		<table class="table">
			<tr><th>RANK</th><th>작품</th><th>구분</th><th>담은 회원</th><th></th></tr>
<% for ( String[] r : rows ) {
	boolean inCart = "1".equals( r[6] ); %>
			<tr>
				<td class="rank"><%= h( r[0] ) %></td>
				<td><%= h( r[2] ) %> <small><%= h( r[4] ) %></small></td>
				<td><%= typeLabel( r[3] ) %></td>
				<td class="num"><%= h( r[5] ) %>명</td>
				<td>
					<form method="post" action="<%= inCart ? "cartDeleteSQL.jsp" : "cartInsertSQL.jsp" %>">
						<input type="hidden" name="title_id" value="<%= h( r[1] ) %>">
						<input type="hidden" name="back" value="ranking.jsp<%= "all".equals( type ) ? "" : "?type=" + type %>">
						<button class="btn small<%= inCart ? " ghost" : "" %>" type="submit"><%= inCart ? "✓ 담김" : "담기" %></button>
					</form>
				</td>
			</tr>
<% } %>
<% if ( rows.isEmpty() && error == null ) { %>
			<tr><td colspan="5" class="empty-msg">아직 카트에 담긴 작품이 없습니다.</td></tr>
<% } %>
		</table>
<%@ include file="footer.jsp" %>

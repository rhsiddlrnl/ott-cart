<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" import="java.util.*, java.net.URLEncoder" %>
<%@ include file="SQLconstants.jsp" %>
<%@ include file="util.jsp" %>
<%@ include file="log.jsp" %>
<%
	// 이전 페이지에서 전달 받은 검색어, 장르 확인
	request.setCharacterEncoding( "UTF-8" );
	String keyword = request.getParameter( "keyword" );
	keyword = ( keyword == null ) ? "" : keyword.trim();
	int genreId = toInt( request.getParameter( "genre" ), 0 );
	String flash = takeFlash( session );
	String error = null;

	List<String[]> genres = new ArrayList<>();
	List<String[]> results = new ArrayList<>();

	// 예제 : "select * from book where title like '%" + message + "%'"  → 문자열 이어붙이기 (SQL Injection 위험)
	// 수정 : ? 자리에 값만 따로 전달하는 PreparedStatement, 장르·시청방법을 JOIN 으로 함께 조회
	String query = "SELECT t.title_id, t.name, t.title_type, t.release_year, t.poster_url, "
		+ GENRES_SUBQUERY + " AS genres, "
		+ OPTIONS_SUBQUERY + " AS options, "
		+ "EXISTS (SELECT 1 FROM cart_items c WHERE c.user_id = ? AND c.title_id = t.title_id) AS in_cart "
		+ "FROM titles t "
		+ "WHERE t.name LIKE ? "
		+ "AND ( ? = 0 OR EXISTS (SELECT 1 FROM title_genres tg WHERE tg.title_id = t.title_id AND tg.genre_id = ?) ) "
		+ "ORDER BY t.name";

	// try-with-resources : 예외가 나도 ResultSet, Statement, Connection 이 자동으로 close 됨
	try ( Connection con = getConnection() )
	{
		// 장르 선택 목록
		try ( Statement stmt = con.createStatement();
		      ResultSet rs = stmt.executeQuery( "SELECT genre_id, name FROM genres ORDER BY name" ) )
		{
			while ( rs.next() )
				genres.add( new String[] { rs.getString( "genre_id" ), rs.getString( "name" ) } );
		}

		// 작품 검색
		try ( PreparedStatement ps = con.prepareStatement( query ) )
		{
			ps.setInt( 1, DEMO_USER_ID );
			ps.setString( 2, likePattern( keyword ) );
			ps.setInt( 3, genreId );
			ps.setInt( 4, genreId );
			try ( ResultSet rs = ps.executeQuery() )
			{
				while ( rs.next() )
					results.add( new String[] {
						rs.getString( "title_id" ), rs.getString( "name" ), rs.getString( "title_type" ),
						rs.getString( "release_year" ), rs.getString( "poster_url" ), rs.getString( "genres" ),
						rs.getString( "options" ), rs.getString( "in_cart" ) } );
			}
		}
	}
	// 예외 처리 : 예제는 오류를 message 에 담고 화면에 보여주지 않았음 → 화면과 로그에 오류로 표시
	catch ( Exception e )
	{
		error = e.getMessage();
	}

	// 로그 데이터 추출
	writeLog( "search", ( error != null ) ? "ERROR " + error
		: "keyword=" + keyword + ", genre=" + genreId + ", results=" + results.size(), request, session );

	String back = "search.jsp?keyword=" + URLEncoder.encode( keyword, "UTF-8" ) + ( genreId > 0 ? "&genre=" + genreId : "" );
	String navActive = "search";
%>
<%@ include file="header.jsp" %>
		<h1>작품 검색</h1>
		<form class="search" method="get" action="search.jsp">
			<input type="text" name="keyword" value="<%= h( keyword ) %>" placeholder="작품 제목 (비우면 전체)">
			<select name="genre">
				<option value="0">전체 장르</option>
<% for ( String[] g : genres ) { %>
				<option value="<%= h( g[0] ) %>"<%= g[0].equals( String.valueOf( genreId ) ) ? " selected" : "" %>><%= h( g[1] ) %></option>
<% } %>
			</select>
			<button class="btn" type="submit">검색</button>
		</form>

<% if ( error != null ) { %>
		<p class="error">DB 오류 : <%= h( error ) %></p>
<% } %>
		<p class="count">검색 결과 <b><%= results.size() %></b>편</p>

		<div class="grid">
<% for ( String[] r : results ) {
	boolean inCart = "1".equals( r[7] ); %>
			<article class="card">
				<%= poster( r[4], r[1] ) %>
				<div class="body">
					<h2><%= h( r[1] ) %></h2>
					<p class="meta"><%= typeLabel( r[2] ) %> · <%= h( r[3] ) %><%= ( r[5] != null ) ? " · " + h( r[5] ) : "" %></p>
					<div class="chips"><%= optionChips( r[6] ) %></div>
					<form method="post" action="<%= inCart ? "cartDeleteSQL.jsp" : "cartInsertSQL.jsp" %>">
						<input type="hidden" name="title_id" value="<%= h( r[0] ) %>">
						<input type="hidden" name="back" value="<%= h( back ) %>">
						<button class="btn<%= inCart ? " ghost" : "" %>" type="submit"><%= inCart ? "✓ 담김 · 빼기" : "카트 담기" %></button>
					</form>
				</div>
			</article>
<% } %>
		</div>
<%@ include file="footer.jsp" %>

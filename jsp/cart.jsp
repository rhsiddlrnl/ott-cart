<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" import="java.util.*" %>
<%@ include file="SQLconstants.jsp" %>
<%@ include file="util.jsp" %>
<%@ include file="log.jsp" %>
<%
	request.setCharacterEncoding( "UTF-8" );
	String flash = takeFlash( session );
	String error = null;

	List<String[]> items = new ArrayList<>();
	List<String[]> coverage = new ArrayList<>();
	long rentTotal = 0;
	int noRent = 0;

	// 카트 작품 + 작품별 가장 싼 대여 가격
	String itemQuery = "SELECT t.title_id, t.name, t.title_type, t.release_year, t.poster_url, "
		+ OPTIONS_SUBQUERY + " AS options, "
		+ "(SELECT MIN(a.price) FROM availability a WHERE a.title_id = t.title_id AND a.access_type_id = 2) AS min_rent "
		+ "FROM cart_items c JOIN titles t ON t.title_id = c.title_id "
		+ "WHERE c.user_id = ? "
		+ "ORDER BY c.added_at, t.name";

	// 서비스별로 카트 작품을 몇 편 구독으로 볼 수 있는지 : 2편 이상이면 구독이 대여보다 유리할 수 있음
	String coverageQuery = "SELECT s.name, COUNT(*) AS cnt, GROUP_CONCAT(t.name ORDER BY t.name SEPARATOR ', ') AS names "
		+ "FROM cart_items c "
		+ "JOIN availability a ON a.title_id = c.title_id AND a.access_type_id = 1 "
		+ "JOIN services s ON s.service_id = a.service_id "
		+ "JOIN titles t ON t.title_id = c.title_id "
		+ "WHERE c.user_id = ? "
		+ "GROUP BY s.service_id, s.name "
		+ "ORDER BY cnt DESC, s.name";

	try ( Connection con = getConnection() )
	{
		try ( PreparedStatement ps = con.prepareStatement( itemQuery ) )
		{
			ps.setInt( 1, DEMO_USER_ID );
			try ( ResultSet rs = ps.executeQuery() )
			{
				while ( rs.next() )
				{
					String minRent = rs.getString( "min_rent" );
					if ( minRent == null ) noRent++; else rentTotal += rs.getLong( "min_rent" );
					items.add( new String[] {
						rs.getString( "title_id" ), rs.getString( "name" ), rs.getString( "title_type" ),
						rs.getString( "release_year" ), rs.getString( "poster_url" ), rs.getString( "options" ), minRent } );
				}
			}
		}

		try ( PreparedStatement ps = con.prepareStatement( coverageQuery ) )
		{
			ps.setInt( 1, DEMO_USER_ID );
			try ( ResultSet rs = ps.executeQuery() )
			{
				while ( rs.next() )
					coverage.add( new String[] { rs.getString( "name" ), rs.getString( "cnt" ), rs.getString( "names" ) } );
			}
		}
	}
	catch ( Exception e )
	{
		error = e.getMessage();
	}

	// 로그 데이터 추출
	writeLog( "cart_view", ( error != null ) ? "ERROR " + error : "items=" + items.size(), request, session );

	String navActive = "cart";
%>
<%@ include file="header.jsp" %>
		<h1>내 카트</h1>

<% if ( error != null ) { %>
		<p class="error">DB 오류 : <%= h( error ) %></p>
<% } else if ( items.isEmpty() ) { %>
		<p class="empty-msg">카트가 비어 있습니다. <a href="search.jsp">작품 검색</a>에서 보고 싶은 작품을 담아 보세요.</p>
<% } else { %>
		<div class="summary">
			<div><span>담은 작품</span><b><%= items.size() %>편</b></div>
			<div><span>모두 대여하면</span><b><%= won( rentTotal ) %></b><% if ( noRent > 0 ) { %><small>대여 불가 <%= noRent %>편 제외</small><% } %></div>
		</div>

		<ul class="cart-list">
<% for ( String[] r : items ) { %>
			<li>
				<%= poster( r[4], r[1] ) %>
				<div class="body">
					<h2><%= h( r[1] ) %> <small><%= typeLabel( r[2] ) %> · <%= h( r[3] ) %></small></h2>
					<div class="chips"><%= optionChips( r[5] ) %></div>
				</div>
				<form method="post" action="cartDeleteSQL.jsp">
					<input type="hidden" name="title_id" value="<%= h( r[0] ) %>">
					<input type="hidden" name="back" value="cart.jsp">
					<button class="btn ghost" type="submit">빼기</button>
				</form>
			</li>
<% } %>
		</ul>

		<h2 class="section">서비스별로 볼 수 있는 작품</h2>
		<table class="table">
			<tr><th>서비스</th><th>구독으로 볼 수 있는 작품 수</th><th>작품</th></tr>
<% for ( String[] c : coverage ) { %>
			<tr><td><%= h( c[0] ) %></td><td class="num"><%= h( c[1] ) %>편</td><td><%= h( c[2] ) %></td></tr>
<% } %>
		</table>
		<p class="note">다음 단계 : plans(요금제) 가격을 입력하면 구독 + 대여를 섞은 최저 비용 조합을 계산합니다.</p>
<% } %>
<%@ include file="footer.jsp" %>

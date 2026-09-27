<%@ page pageEncoding="UTF-8" %>
<%!
	// 작품의 장르 목록 : "드라마, 스릴러"
	static final String GENRES_SUBQUERY =
		"(SELECT GROUP_CONCAT(g.name ORDER BY g.name SEPARATOR ', ') "
		+ "FROM title_genres tg JOIN genres g ON g.genre_id = tg.genre_id "
		+ "WHERE tg.title_id = t.title_id)";

	// 작품을 볼 수 있는 방법 : "1:Netflix:|2:Google Play:3000" (시청방식:서비스:가격)
	static final String OPTIONS_SUBQUERY =
		"(SELECT GROUP_CONCAT(CONCAT(a.access_type_id, ':', s.name, ':', IFNULL(a.price, '')) "
		+ "ORDER BY a.access_type_id, s.name SEPARATOR '|') "
		+ "FROM availability a JOIN services s ON s.service_id = a.service_id "
		+ "WHERE a.title_id = t.title_id)";

	// HTML 출력용 이스케이프 : <script> 등 사용자 입력이 태그로 실행되지 않도록 (XSS 방지)
	static String h( String s )
	{
		if ( s == null ) return "";
		StringBuilder b = new StringBuilder( s.length() );
		for ( char c : s.toCharArray() )
		{
			switch ( c )
			{
				case '<':  b.append( "&lt;" );   break;
				case '>':  b.append( "&gt;" );   break;
				case '&':  b.append( "&amp;" );  break;
				case '"':  b.append( "&quot;" ); break;
				case '\'': b.append( "&#39;" );  break;
				default:   b.append( c );
			}
		}
		return b.toString();
	}

	// 숫자 전달인자 확인 : 숫자가 아니면 기본값
	static int toInt( String s, int def )
	{
		try { return Integer.parseInt( s.trim() ); }
		catch ( Exception e ) { return def; }
	}

	// LIKE 검색어 : 사용자가 입력한 %, _ 는 와일드카드가 아닌 글자로 취급
	static String likePattern( String keyword )
	{
		return "%" + keyword.replace( "\\", "\\\\" ).replace( "%", "\\%" ).replace( "_", "\\_" ) + "%";
	}

	static String won( long n )
	{
		return String.format( "%,d원", n );
	}

	static String typeLabel( String titleType )
	{
		return "movie".equals( titleType ) ? "영화" : "드라마";
	}

	// 포스터 이미지 (없으면 제목 첫 글자)
	static String poster( String url, String name )
	{
		if ( url == null || url.isEmpty() )
			return "<div class='poster empty'>" + h( name == null || name.isEmpty() ? "?" : name.substring( 0, 1 ) ) + "</div>";
		return "<img class='poster' src='" + h( url ) + "' alt='" + h( name ) + " 포스터'>";
	}

	// OPTIONS_SUBQUERY 결과를 구독 / 대여 / 구매 칩으로 출력
	static String optionChips( String raw )
	{
		if ( raw == null || raw.isEmpty() ) return "<span class='chip none'>국내 시청 방법 없음</span>";
		StringBuilder b = new StringBuilder();
		for ( String item : raw.split( "\\|" ) )
		{
			String[] f = item.split( ":", 3 );
			if ( f.length < 3 ) continue;
			if ( "1".equals( f[0] ) )
				b.append( "<span class='chip sub'>" ).append( h( f[1] ) ).append( " 구독</span>" );
			else
				b.append( "<span class='chip " ).append( "2".equals( f[0] ) ? "rent'>" : "buy'>" )
				 .append( h( f[1] ) ).append( "2".equals( f[0] ) ? " 대여 " : " 구매 " )
				 .append( won( toInt( f[2], 0 ) ) ).append( "</span>" );
		}
		return b.toString();
	}

	// 다음 페이지로 메시지 전달 : 예제의 hidden form + alert 대신 세션에 한 번만 보관 (새로고침해도 재전송 안 됨)
	static void setFlash( HttpSession session, String message )
	{
		session.setAttribute( "flash", message );
	}

	static String takeFlash( HttpSession session )
	{
		String message = (String) session.getAttribute( "flash" );
		session.removeAttribute( "flash" );
		return message;
	}

	// 처리 후 돌아갈 페이지 : 우리 사이트의 페이지만 허용 (외부 사이트로 튕기는 오픈 리다이렉트 방지)
	static String safeBack( String back )
	{
		return ( back != null && back.matches( "(search|cart|ranking)\\.jsp(\\?[^\\r\\n]*)?" ) ) ? back : "search.jsp";
	}
%>

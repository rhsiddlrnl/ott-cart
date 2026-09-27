<%@ page pageEncoding="UTF-8" import="java.io.*, java.nio.charset.StandardCharsets, java.time.LocalDateTime, java.time.format.DateTimeFormatter" %>
<%!
	static final DateTimeFormatter LOG_TIME = DateTimeFormatter.ofPattern( "yyyy-MM-dd HH:mm:ss" );

	// 탭, 줄바꿈이 들어가면 로그 한 줄이 여러 줄로 깨지므로 공백으로 바꿈
	static String oneLine( String s )
	{
		return ( s == null ) ? "" : s.replaceAll( "[\\t\\r\\n]+", " " );
	}

	// 예제 대비 추가 항목 : Action(행동 종류), UserID  → 로그데이터 분석 시 행동별 집계 가능
	public void writeLog( String action, String message, HttpServletRequest request, HttpSession session )
	{
		// 로그 파일 : 현재 JSP 와 같은 폴더의 log.txt (예제처럼 tomcat 경로를 직접 적지 않아도 됨)
		String pagePath = request.getServletContext().getRealPath( request.getServletPath() );
		if ( pagePath == null ) return;
		File logFile = new File( new File( pagePath ).getParentFile(), "log.txt" );

		try ( Writer writer = new BufferedWriter( new OutputStreamWriter( new FileOutputStream( logFile, true ), StandardCharsets.UTF_8 ) ) )
		{
			// 로그 데이터 출력
			writer.append( "\nTime:\t" + LocalDateTime.now().format( LOG_TIME )	// 접속 시간
				+ "\tSessionID:\t" + session.getId()					// 접속 ID
				+ "\tUserID:\t" + DEMO_USER_ID						// 회원 ID (로그인 전까지 데모 회원)
				+ "\tAction:\t" + action						// search, cart_add, cart_remove, cart_view, ranking_view
				+ "\tURI:\t" + request.getRequestURI()					// 현재 페이지
				+ "\tPrevious:\t" + oneLine( request.getHeader( "referer" ) )		// 접속 경로(이전페이지)
				+ "\tBrowser:\t" + oneLine( request.getHeader( "User-Agent" ) )	// 접속 브라우저
				+ "\tMessage:\t" + oneLine( message ) );
		}
		// 예외 처리 : 로그 실패가 페이지 오류로 번지지 않도록
		catch ( IOException e )
		{
			e.printStackTrace();
		}
	}
%>

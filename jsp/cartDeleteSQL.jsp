<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ include file="SQLconstants.jsp" %>
<%@ include file="util.jsp" %>
<%@ include file="log.jsp" %>
<%
	// 이전 페이지에서 전달 받은 작품 ID, 돌아갈 페이지 확인
	request.setCharacterEncoding( "UTF-8" );
	int titleId = toInt( request.getParameter( "title_id" ), -1 );
	String back = safeBack( request.getParameter( "back" ) );
	String message;

	// 입력값 검증 : 예제는 "1' or '1'='1" 을 입력하면 book 전체가 삭제되었음
	if ( !"POST".equals( request.getMethod() ) || titleId < 0 )
	{
		message = "잘못된 요청입니다.";
	}
	else
	{
		try ( Connection con = getConnection() )
		{
			String name = null;
			try ( PreparedStatement ps = con.prepareStatement( "SELECT name FROM titles WHERE title_id = ?" ) )
			{
				ps.setInt( 1, titleId );
				try ( ResultSet rs = ps.executeQuery() ) { if ( rs.next() ) name = rs.getString( "name" ); }
			}

			// 카트에서 빼기 실행 : 작품(titles)이 아니라 내 카트의 한 행(cart_items)만 삭제
			try ( PreparedStatement ps = con.prepareStatement( "DELETE FROM cart_items WHERE user_id = ? AND title_id = ?" ) )
			{
				ps.setInt( 1, DEMO_USER_ID );
				ps.setInt( 2, titleId );
				if ( ps.executeUpdate() > 0 )
					message = "'" + name + "'을(를) 카트에서 뺐습니다.";
				else
					message = "카트에 없는 작품입니다.";
			}
		}
		// 예외 처리
		catch ( Exception e )
		{
			message = "DB 오류 : " + e.getMessage();
		}
	}

	// 로그 데이터 추출
	writeLog( "cart_remove", "title_id=" + titleId + ", " + message, request, session );

	// 다음 페이지로 메시지 전달 후 이동 (Post/Redirect/Get)
	setFlash( session, message );
	response.sendRedirect( back );
%>

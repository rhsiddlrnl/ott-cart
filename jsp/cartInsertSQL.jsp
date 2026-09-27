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

	// 입력값 검증 : 데이터를 바꾸는 요청은 POST 만, 작품 ID 는 숫자만
	if ( !"POST".equals( request.getMethod() ) || titleId < 0 )
	{
		message = "잘못된 요청입니다.";
	}
	else
	{
		try ( Connection con = getConnection() )
		{
			// 작품 존재 확인
			String name = null;
			try ( PreparedStatement ps = con.prepareStatement( "SELECT name FROM titles WHERE title_id = ?" ) )
			{
				ps.setInt( 1, titleId );
				try ( ResultSet rs = ps.executeQuery() ) { if ( rs.next() ) name = rs.getString( "name" ); }
			}

			if ( name == null )
			{
				message = "ID " + titleId + "인 작품을 찾을 수 없습니다.";
			}
			else
			{
				// 카트에 담기 실행 (예제 insertSQL.jsp 의 INSERT → cart_items)
				try ( PreparedStatement ps = con.prepareStatement( "INSERT INTO cart_items ( user_id, title_id ) VALUES ( ?, ? )" ) )
				{
					ps.setInt( 1, DEMO_USER_ID );
					ps.setInt( 2, titleId );
					ps.executeUpdate();
					message = "'" + name + "'을(를) 카트에 담았습니다.";
				}
				// 복합 PK (user_id, title_id) 가 같은 작품 중복 담기를 막음
				catch ( SQLIntegrityConstraintViolationException e )
				{
					message = "'" + name + "'은(는) 이미 카트에 있습니다.";
				}
			}
		}
		// 예외 처리
		catch ( Exception e )
		{
			message = "DB 오류 : " + e.getMessage();
		}
	}

	// 로그 데이터 추출
	writeLog( "cart_add", "title_id=" + titleId + ", " + message, request, session );

	// 다음 페이지로 메시지 전달 후 이동 (Post/Redirect/Get)
	setFlash( session, message );
	response.sendRedirect( back );
%>

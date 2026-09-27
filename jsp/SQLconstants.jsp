<%@ page pageEncoding="UTF-8" import="java.sql.*" %>
<%!
	// 예제의 스크립트릿 지역변수를 선언부(static 필드)로 옮김 : 선언부 메서드(getConnection)에서도 상수를 쓸 수 있도록

	// MySQL ID : MySQL 설치시 아이디 ex) root, test, ...
	static final String mySQL_id = "root";

	// MySQL Password
	static final String mySQL_password = "MySQL Password";

	// MySQL Database
	static final String mySQL_database = "jdbc:mysql://localhost:3306/ott_cart?useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Seoul";

	// JDBC Driver : Connector/J 8 이상은 com.mysql.cj.jdbc.Driver
	//               (ClassNotFoundException 이 나면 예제에서 동작했던 com.mysql.jdbc.Driver 로 바꿀 것)
	static final String jdbc_driver = "com.mysql.cj.jdbc.Driver";

	// 로그인 기능 전까지 사용할 데모 회원 (SQL.txt 의 users.user_id = 1)
	static final int DEMO_USER_ID = 1;

	// JDBC 연결 요청 및 승인 : 모든 페이지가 같은 코드를 쓰도록 한 곳에 모음
	static Connection getConnection() throws Exception
	{
		Class.forName( jdbc_driver );
		return DriverManager.getConnection( mySQL_database, mySQL_id, mySQL_password );
	}
%>

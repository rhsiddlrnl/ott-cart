# OTT Cart: JSP 예제 프로그램 분석 및 수정 (9/29 발표)

[CodeReading101/Web-DB](https://github.com/CodeReading101/Web-DB) 예제(book = 검색, game = 랭킹)를 분석하고,
9/22에 발표한 **OTT Cart DB 테이블 구조**에 맞게 수정한 코드입니다.

---

## 1. 예제 → OTT Cart 대응표

| 예제 파일 | 예제 기능 | 수정 후 파일 | OTT Cart 기능 | 사용 테이블 |
|---|---|---|---|---|
| book/search.jsp + selectSQL.jsp | 책 제목 검색 (`LIKE`) | **search.jsp** | 작품 제목 + 장르 검색, 볼 수 있는 서비스 표시 | titles, genres, title_genres, availability, services |
| book/insert.jsp + insertSQL.jsp | 새 책 등록 (`INSERT`) | **cartInsertSQL.jsp** | 작품을 카트에 담기 | cart_items |
| book/delete.jsp + deleteSQL.jsp | 책 삭제 (`DELETE`) | **cartDeleteSQL.jsp** | 카트에서 빼기 | cart_items |
| (없음) | | **cart.jsp** | 내 카트, 모두 대여할 때 합계, 서비스별 구독 가능 작품 수 | cart_items, availability, services |
| game/selectSQL.jsp | 게임 점수 랭킹 (`ORDER BY score DESC`) | **ranking.jsp** | 카트에 많이 담긴 작품 TOP 10 (`GROUP BY`, `RANK()`) | cart_items, titles |
| SQLconstants.jsp | DB 접속 상수 | **SQLconstants.jsp** | DB = `ott_cart`, 연결 함수 `getConnection()` | |
| log.jsp | 접속 로그 기록 | **log.jsp** | Action, UserID 항목 추가 | |
| book/SQL.txt, game/SQL.txt | 테이블 1개 | **SQL.txt** | 테이블 12개 + 데모 데이터 | 전체 |
| | | util.jsp, header.jsp, footer.jsp, style.css | 공통 함수, 공통 화면 | |

---

## 2. 예제 분석 요점 (발표 "분석" 파트)

### 페이지 흐름 (book 예제)
```
search.jsp ──include──▶ selectSQL.jsp        SELECT ... LIKE → 목록 출력
   ├─ [새 책 추가] insert.jsp ──POST──▶ insertSQL.jsp   INSERT
   └─ [책 삭제]   delete.jsp ──POST──▶ deleteSQL.jsp   DELETE
                                   └─ hidden form 자동 submit ──▶ search.jsp (alert 로 결과 표시)
```

### 3장 개념과 예제 코드 대응
| 3장 개념 | 예제 코드 위치 |
|---|---|
| 디렉티브 `<%@ page %>`, `<%@ include %>` | 모든 파일 첫 줄, `search.jsp`가 `selectSQL.jsp`를 포함 |
| 스크립트릿 `<% %>` | JDBC 코드 전체 |
| 표현식 `<%= %>` | `value=' * <%=message%>'` |
| 선언부 `<%! %>` | `log.jsp`의 `writeLog()` 메서드 |
| 기본객체 request / out / session | `request.getParameter()`, `out.print()`, `session.getId()` |
| JDBC 순서 | `Class.forName` → `getConnection` → `createStatement` → `executeQuery/executeUpdate` → `close` |
| GET / POST | 검색 form(POST), 결과 전달용 hidden form(POST) |

---

## 3. 발견한 문제점과 수정 내용 (발표 "수정" 파트)

| # | 예제의 문제 | 재현 방법 | 수정 |
|---|---|---|---|
| 1 | **SQL Injection**: 입력값을 SQL 문자열에 그대로 이어 붙임 | delete.jsp 에 `1' or '1'='1` 입력 → **책 전체 삭제** | 모든 쿼리를 `PreparedStatement` + `?` 로 변경 |
| 2 | 작은따옴표가 든 제목이 등록되지 않음 | 제목에 `Can't Stop` 입력 → SQL 문법 오류 | 1번 수정으로 해결 |
| 3 | **XSS**: 결과 메시지를 JS 문자열/HTML 에 그대로 출력 | 제목에 `<b>굵게</b>` 등록 → 목록에서 태그가 실행됨 | 출력할 때 `h()` 로 HTML 이스케이프 |
| 4 | 예외가 나면 `close()` 가 실행되지 않음 (연결 누수) | SQL 오류 발생 시 | `try-with-resources` 로 자동 close |
| 5 | 검색 오류를 숨기고 로그에 "관련된 책을 찾았습니다"로 기록 | DB 비밀번호를 틀리게 설정 | 화면에 오류 표시, 로그에 `ERROR` 기록 |
| 6 | 새로고침하면 결과 메시지 alert 가 반복되고, 등록/삭제 결과를 alert 로만 알림 | 등록 후 F5 | Post/Redirect/Get + 세션 메시지(`flash`) |
| 7 | 입력값 검증 없음 (빈 ID, 문자 ID, 중복 ID 는 DB 오류 메시지 그대로 노출) | ID 에 `abc` 입력 | 숫자 확인, 중복은 친절한 메시지(복합 PK 활용) |
| 8 | game 랭킹: `title` 전달인자를 SQL 에 붙임, 동점도 순위가 다름 | `?title=' or '1'='1` | 허용값(all/movie/tv)만 사용, `RANK()` 로 동점 처리 |
| 9 | `new String(query.getBytes("utf-8"))` : 의미 없는 변환 (인코딩 깨짐 원인) | | 삭제 |
| 10 | 로그 파일 경로를 tomcat 버전별로 직접 적어야 함 | tomcat8 ↔ tomcat10 | `getRealPath()` 로 JSP 와 같은 폴더에 기록 |
| 11 | 로그에 "무슨 행동"인지 없음 → 분석이 어려움 | | `Action`(search, cart_add, cart_remove, cart_view, ranking_view), `UserID` 추가 |
| 12 | `com.mysql.jdbc.Driver` 는 구버전 이름 | | `com.mysql.cj.jdbc.Driver` (안 되면 예제 값으로) |

---

## 4. 서버에 올리고 실행하기 (AWS)

1. **SQL**: phpMyAdmin 에서 `ott_cart` DB 를 만들고 `SQL.txt` 의 2) ~ 4) 실행
2. **파일 복사**: 이 `jsp` 폴더를 서버의 `webapps/ROOT/ott-cart/jsp/` 로 복사
   (GitHub 에 올렸다면 `cd /var/lib/tomcat10/webapps/ROOT/ && sudo git clone <팀 저장소 URL>`)
3. **DB 비밀번호**: `sudo vi SQLconstants.jsp` 에서 `mySQL_password` 수정
4. **로그 파일 권한**:
   ```bash
   cd /var/lib/tomcat10/webapps/ROOT/ott-cart/jsp
   sudo touch log.txt && sudo chmod 777 log.txt
   ```
5. **접속**: `http://IP주소:8080/ott-cart/jsp/search.jsp`
6. **로그 확인**: `tail -f log.txt` 를 띄워 두고 검색·담기·빼기를 하며 줄이 추가되는지 확인

> `ClassNotFoundException` 이 나면 `SQLconstants.jsp` 의 `jdbc_driver` 를 예제에서 동작했던 값(`com.mysql.jdbc.Driver`)으로 바꿉니다.
> 랭킹의 `RANK()` 는 MySQL 8 / MariaDB 10.2 이상이 필요합니다.

---

## 5. 시연 시나리오 (약 3분)

1. **원본 예제의 문제 보여주기**: book/delete.jsp 에 `1' or '1'='1` 입력 → 책 목록이 모두 사라짐
2. **search.jsp**: "인" 검색 → 인셉션·인터스텔라, 장르 "SF" 필터, 서비스별 구독/대여 칩
3. **담기**: 기생충·인터스텔라·데모 영화 A 담기 → 상단 메시지 확인 → F5 해도 다시 담기지 않음
4. **cart.jsp**: 모두 대여 합계, "Netflix 로 2편" 같은 서비스별 표 → "다음 단계에서 최저 조합 계산" 예고
5. **ranking.jsp**: 방금 담은 작품의 순위가 올라감, 영화/드라마 탭
6. **공격 재시도**: 검색창에 `' or '1'='1`, `<script>alert(1)</script>` 입력 → 그냥 글자로 검색됨
7. **log.txt**: 방금 한 행동이 Action 별로 기록된 것 보여주기 → 11/17 로그데이터 분석으로 이어짐

---

## 6. 발표 구성 (추천)

1. 표지: 팀 C · OTT Cart · JSP 예제 분석 및 수정
2. 예제 소개와 실행 화면 (book, game)
3. 예제 구조: 페이지 흐름도, 파일별 역할
4. 코드 분석: 3장 JSP 구성요소 · JDBC 실행 순서와 대응
5. 문제점 발견: SQL Injection 시연 등 (위 표 1 ~ 12 중 핵심 4 ~ 5개)
6. OTT Cart 로 수정: 대응표, 우리 테이블 12개 중 이번에 쓴 테이블
7. 수정 코드 before / after (PreparedStatement, try-with-resources, 출력 이스케이프, RANK())
8. 실행 결과 화면 (검색 → 카트 → 랭킹) 과 로그
9. 다음 단계: 요금제 입력 → 최저 비용 조합 계산, 로그인, TMDB 연동

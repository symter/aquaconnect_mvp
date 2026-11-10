// 관리원 구성원 역할. 원장(director)만 관리 기능(직원 관리·초대·관리원 정보
// 수정·변경 이력·남의 메모 수정/삭제)을 쓸 수 있고, 원장 지정·해제는
// 관리자 대시보드(/api/admin)에서만 한다 — 앱 안에서는 원장을 만들거나
// 바꿀 수 없다.

export const ROLE_LABEL = { director: '원장', staff: '수산질병관리사', employee: '직원' };

// 앱(원장)이 직원에게 줄 수 있는 역할 — 초대 포함.
export const IN_APP_ROLES = ['staff', 'employee'];

// 관리자 대시보드가 줄 수 있는 역할.
export const ADMIN_ROLES = ['director', 'staff', 'employee'];

export const isDirector = (member) => member?.role === 'director';

export const DIRECTOR_ONLY = '원장만 사용할 수 있는 기능입니다.';

export const ROLE_ORDER_SQL = (col) => `case ${col} when 'director' then 0 when 'staff' then 1 else 2 end`;

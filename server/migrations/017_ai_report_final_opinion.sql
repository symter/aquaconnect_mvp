-- AI 관리 리포트의 '전문가 최종 의견'(symterAI 리포트 양식의 마지막 칸). 전문가가 확정 전에 적는다.
alter table ai_reports add column final_opinion text not null default '';

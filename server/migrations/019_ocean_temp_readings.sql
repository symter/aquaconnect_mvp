-- 전국 관측소 수온 이력 — 서버가 1시간마다 NIFS 실시간 해양관측(risaList)을 받아 쌓는다(lib/oceanHistory.js).
-- AI 리포트의 '기간 일 평균 수온'은 이 표로 계산한다. 2개월이 지난 행은 서버가 자동으로 지운다.
-- 같은 관측소·층·관측 시각은 한 번만 저장한다(같은 시각 자료를 다시 받아도 중복되지 않음).
create table ocean_temp_readings (
  station_code text not null,
  station_name text not null,
  layer text not null,
  observed_at timestamptz not null,
  water_temp_c real not null,
  status text not null default '',
  fetched_at timestamptz not null default now(),
  primary key (station_code, layer, observed_at)
);
create index ocean_temp_readings_observed_at_idx on ocean_temp_readings(observed_at);

-- 완료 재시도에서 MMR/보상을 다시 반영하지 않고 최초 결과를 반환한다.
CREATE TABLE lockstep_completed_results (
    session_id varchar(128) PRIMARY KEY,
    initial_hash varchar(64) NOT NULL CHECK (initial_hash ~ '^[0-9a-f]{64}$'),
    confirmed_input_hash varchar(64) NOT NULL CHECK (confirmed_input_hash ~ '^[0-9a-f]{64}$'),
    simulation_version varchar(64) NOT NULL,
    left_user_id bigint NOT NULL,
    right_user_id bigint NOT NULL,
    confirmed_frames integer NOT NULL CHECK (confirmed_frames BETWEEN 1 AND 12000),
    statistic_game_id bigint NOT NULL REFERENCES statistic_games(id),
    result_json jsonb NOT NULL CHECK (jsonb_typeof(result_json) = 'object'),
    completed_at timestamptz NOT NULL DEFAULT now(),
    CHECK (left_user_id <> 0 AND right_user_id <> 0 AND left_user_id <> right_user_id)
);

COMMENT ON TABLE lockstep_completed_results IS
    '서버 소유 초기 상태와 확정 입력을 재생하여 검증하고 저장한 lockstep 완료 결과';

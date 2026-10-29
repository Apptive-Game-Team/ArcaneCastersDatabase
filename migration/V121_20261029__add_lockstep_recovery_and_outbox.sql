-- 확정 프레임을 공개하기 전 기록하고 같은 서버의 다음 프로세스가 최초 상태부터 복구한다.
CREATE TABLE lockstep_server_leases (
    owner_key text PRIMARY KEY,
    lease_token varchar(64) NOT NULL,
    lease_until timestamptz NOT NULL
);
CREATE TABLE lockstep_sessions (
    session_id varchar(128) PRIMARY KEY,
    owner_key text NOT NULL,
    placement_instance_id varchar(128) NOT NULL,
    attempt_id varchar(128) UNIQUE,
    start_json jsonb NOT NULL CHECK (jsonb_typeof(start_json) = 'object'),
    creation_json jsonb,
    state_json jsonb NOT NULL CHECK (jsonb_typeof(state_json) = 'object'),
    revision bigint NOT NULL DEFAULT 0 CHECK (revision >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL DEFAULT now() + interval '30 minutes',
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX lockstep_sessions_owner_idx ON lockstep_sessions(owner_key, expires_at);
CREATE TABLE lockstep_frames (
    session_id varchar(128) NOT NULL REFERENCES lockstep_sessions(session_id),
    tick integer NOT NULL CHECK (tick BETWEEN 0 AND 11999),
    frame_json jsonb NOT NULL CHECK (jsonb_typeof(frame_json) = 'object'),
    PRIMARY KEY (session_id, tick)
);
-- 송신 성공 뒤 ack 전 crash는 중복 전달될 수 있다. 수신자는 session_id로 효과를 멱등 처리한다.
CREATE TABLE lockstep_end_outbox (
    session_id varchar(128) PRIMARY KEY,
    owner_key text NOT NULL,
    instance_id varchar(128) NOT NULL,
    attempts integer NOT NULL DEFAULT 0,
    next_attempt_at timestamptz NOT NULL DEFAULT now(),
    lease_token varchar(64),
    lease_until timestamptz,
    delivered_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX lockstep_end_outbox_pending_idx ON lockstep_end_outbox(owner_key, next_attempt_at)
    WHERE delivered_at IS NULL;
COMMENT ON TABLE lockstep_sessions IS 'lockstep 초기 상태와 미확정 입력 및 checkpoint의 내구 기록';
COMMENT ON TABLE lockstep_frames IS 'DB commit 후 참가자에게 공개한 연속 확정 입력';
COMMENT ON TABLE lockstep_end_outbox IS '결과 저장과 같은 transaction으로 기록하는 로비 종료 알림';

-- provider 가 key 를 거절할 때(401 잘못된 key, 402 잔액 없음, 403 한도 초과) game 서버가 기록한다.
-- unavailable_until 이 CURRENT_TIMESTAMP 보다 뒤이면 lobby 와 game 은 그 provider 를 쓰는 LLM persona 를
-- bot 매칭에서 빼고 rule persona 만 고른다. admin 이 key 를 다시 저장하면 두 컬럼을 NULL 로 되돌린다.
ALTER TABLE "public"."llm_api_keys"
    ADD COLUMN IF NOT EXISTS "unavailable_until" timestamp without time zone,
    ADD COLUMN IF NOT EXISTS "unavailable_reason" character varying(200);

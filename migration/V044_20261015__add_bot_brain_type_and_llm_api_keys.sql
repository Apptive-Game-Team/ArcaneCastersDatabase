-- Bot persona 마다 판단 방식을 고른다.
-- RULE: 기존 rule 기반 BotBrain, JEV: jev-ai.pro decision API, OPENROUTER: OpenRouter chat completions.
-- llm_model 이 NULL 이면 game 서버가 provider 기본 모델을 쓴다.
ALTER TABLE "public"."bot_personas"
    ADD COLUMN IF NOT EXISTS "brain_type" character varying(20) DEFAULT 'RULE' NOT NULL,
    ADD COLUMN IF NOT EXISTS "llm_model" character varying(100);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'bot_personas_brain_type_check') THEN
        ALTER TABLE "public"."bot_personas"
            ADD CONSTRAINT "bot_personas_brain_type_check"
            CHECK (("brain_type")::text = ANY (ARRAY['RULE', 'JEV', 'OPENROUTER']));
    END IF;
END $$;

-- provider 별 API key 한 줄. admin 이 .env 의 LLM_KEY_SECRET 으로 AES-256-GCM 암호화해 저장하고
-- game 서버가 같은 secret 으로 복호화한다. 형식: 'v1:' || base64(iv || ciphertext || tag), AAD 는 provider 이름.
-- key_hint 는 admin 화면 표시용으로 끝 4자리만 담는다.
CREATE TABLE IF NOT EXISTS "public"."llm_api_keys" (
    "provider" character varying(20) NOT NULL PRIMARY KEY,
    "encrypted_key" text NOT NULL,
    "key_hint" character varying(16) NOT NULL,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT "llm_api_keys_provider_check" CHECK (("provider")::text = ANY (ARRAY['JEV', 'OPENROUTER']))
);

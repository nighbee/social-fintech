-- Add honor_score column to profiles table for denormalized leaderboard gold_seals value.
-- Eliminates the JOIN on wallets for every leaderboard profile fetch.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS honor_score INTEGER NOT NULL DEFAULT 0;

-- Backfill existing values from wallets
UPDATE profiles p
SET honor_score = COALESCE(
  (SELECT total_received_amount / 100 FROM wallets w WHERE w.user_id = p.user_id AND w.currency = 'GOLD_SEAL'),
  0
);

-- Trigger function: keep profiles.honor_score in sync with wallets.total_received_amount for GOLD_SEAL
CREATE OR REPLACE FUNCTION sync_profile_honor_score()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    IF NEW.currency = 'GOLD_SEAL' THEN
      UPDATE profiles
      SET honor_score = NEW.total_received_amount / 100
      WHERE user_id = NEW.user_id;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.currency = 'GOLD_SEAL' THEN
      UPDATE profiles
      SET honor_score = 0
      WHERE user_id = OLD.user_id;
    END IF;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_wallets_honor_score ON wallets;
CREATE TRIGGER trg_wallets_honor_score
  AFTER INSERT OR UPDATE OF total_received_amount OR DELETE
  ON wallets
  FOR EACH ROW
  EXECUTE FUNCTION sync_profile_honor_score();

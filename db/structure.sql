DROP TABLE IF EXISTS records;

CREATE TABLE records (
  id BIGSERIAL PRIMARY KEY,
  category TEXT,
  amount NUMERIC(10, 2),
  currency CHAR(3),
  amount_in_eur NUMERIC(10, 2),
  description TEXT NOT NULL,
  payment_type TEXT,
  timestamp TIMESTAMP WITH TIME ZONE NOT NULL
);

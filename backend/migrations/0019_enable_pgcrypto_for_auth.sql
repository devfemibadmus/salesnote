-- Required for crypt()/gen_salt() used by DB-side password hashing and login verification.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

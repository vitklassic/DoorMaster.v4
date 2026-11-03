/*
# Add user roles to profiles

1. Modified Tables
- `profiles`: new column `role` (text, not null, default 'installer'). Allowed values: 'installer' (Монтажник, enters measurements) and 'manager' (Менеджер, views the team feed later).

2. Security
- No policy or grant changes. Users can already read their own profile row; the role is assigned only by the server (default on sign-up). Users cannot update their own role because the profiles table has no UPDATE grant for authenticated users.

3. Notes
- Idempotent: the column is added only if it does not exist yet.
*/

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'installer' CHECK (role IN ('installer', 'manager'));

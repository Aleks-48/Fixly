-- Миграция: Включение RLS и добавление политик для таблиц profiles, messages и calls

-- ==========================================
-- 1. Таблица PROFILES (Профили пользователей)
-- ==========================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Разрешить чтение профилей всем авторизованным пользователям 
-- (чтобы жильцы могли видеть мастеров, председатель — жильцов, и наоборот)
DROP POLICY IF EXISTS "profiles_read_all_authenticated" ON public.profiles;
CREATE POLICY "profiles_read_all_authenticated"
  ON public.profiles
  FOR SELECT
  USING (auth.role() = 'authenticated');

-- Разрешить создание профиля только для самого себя (при регистрации)
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own"
  ON public.profiles
  FOR INSERT
  WITH CHECK (id = auth.uid());

-- Разрешить обновление профиля только его владельцу
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own"
  ON public.profiles
  FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());


-- ==========================================
-- 2. Таблица MESSAGES (Сообщения в чате)
-- ==========================================
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Разрешить просмотр сообщений только участникам переписки (отправителю или получателю)
DROP POLICY IF EXISTS "messages_select_own_chats" ON public.messages;
CREATE POLICY "messages_select_own_chats"
  ON public.messages
  FOR SELECT
  USING (sender_id = auth.uid() OR receiver_id = auth.uid());

-- Разрешить отправку сообщений только от своего лица
DROP POLICY IF EXISTS "messages_insert_own" ON public.messages;
CREATE POLICY "messages_insert_own"
  ON public.messages
  FOR INSERT
  WITH CHECK (sender_id = auth.uid());

-- Разрешить обновление статуса сообщения (например, прочтение is_read или удаление is_deleted) участникам чата
DROP POLICY IF EXISTS "messages_update_own_chats" ON public.messages;
CREATE POLICY "messages_update_own_chats"
  ON public.messages
  FOR UPDATE
  USING (sender_id = auth.uid() OR receiver_id = auth.uid())
  WITH CHECK (sender_id = auth.uid() OR receiver_id = auth.uid());


-- ==========================================
-- 3. Таблица CALLS (Аудио/Видео звонки)
-- ==========================================
ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;

-- Разрешить просмотр информации о звонках только участникам звонка
DROP POLICY IF EXISTS "calls_select_own" ON public.calls;
CREATE POLICY "calls_select_own"
  ON public.calls
  FOR SELECT
  USING (caller_id = auth.uid() OR receiver_id = auth.uid());

-- Разрешить совершение звонка только от своего лица
DROP POLICY IF EXISTS "calls_insert_own" ON public.calls;
CREATE POLICY "calls_insert_own"
  ON public.calls
  FOR INSERT
  WITH CHECK (caller_id = auth.uid());

-- Разрешить обновление статуса звонка (ringing, accepted, ended) участникам звонка
DROP POLICY IF EXISTS "calls_update_own" ON public.calls;
CREATE POLICY "calls_update_own"
  ON public.calls
  FOR UPDATE
  USING (caller_id = auth.uid() OR receiver_id = auth.uid())
  WITH CHECK (caller_id = auth.uid() OR receiver_id = auth.uid());

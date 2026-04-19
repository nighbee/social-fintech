# BrightBund Backend MVP Review Contract

Этот файл задает правила ревью **только backend** части.

## Backend Scope (MVP)

В scope входят:

- `auth` (email/phone/firebase auth, sessions, refresh/logout)
- `feed` (posts/comments/reactions/reports/media upload)
- `map` (region resolve, champions, task lifecycle)
- `economy` интеграции, уже подключенные в backend
- `settings` модуль в текущей серверной реализации
- SQL migrations + auto-migrate на старте API

Любые frontend/UI/дизайн замечания не влияют на backend MVP verdict.

## Acceptance Criteria (обязательные)

Ревьюер проверяет только пункты ниже:

1. Backend поднимается и проходит health-check при валидных env.
2. Миграции применяются консистентно (нет schema drift и “marked as applied, but missing columns”).
3. Критичные тесты проходят:
   - `go test ./internal/modules/auth ./internal/modules/feed ./internal/modules/map`
4. Нет блокирующих P0/P1 багов:
   - crash/panic в runtime
   - auth bypass
   - data loss/corruption
   - неработающие ключевые endpoints из backend scope
5. Детерминизм зафиксирован:
   - tie-break правила в champion/geo
   - weekly-stability по региону
6. Media upload ошибки разделены по типам:
   - invalid type
   - file too large
   - storage unavailable / storage full / permission denied

Если все 6 пунктов Pass — backend считается готовым к MVP.

## Strict Verdict Format

Результат ревью должен быть только:

- `READY_FOR_MVP`
- `NOT_READY_FOR_MVP`

Если `NOT_READY_FOR_MVP`, разрешено перечислять только fail-пункты из Acceptance Criteria выше.

## Non-blocking Improvements

Любые дополнительные идеи разрешены только как `Nice-to-have` и не блокируют MVP, если Acceptance Criteria выполнены.


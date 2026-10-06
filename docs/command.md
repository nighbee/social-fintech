flutter run --debug --flavor dev -t lib/main_dev.dart

docker exec -it brightbund-db psql -U user -d brightbund

cd tests && ./test_economy_cooldown.sh

cd backend && go run ./cmd/migrate -mode migrate

cd backend && go run ./cmd/migrate -mode backfill-gold-weekly -weeks 12

cd backend && go run ./cmd/migrate -mode reconcile-gold-weekly -weeks 12

cd backend && go run ./cmd/migrate -mode backfill-gold-seasonal -weeks 12

cd backend && go run ./cmd/migrate -mode reconcile-gold-seasonal -weeks 12
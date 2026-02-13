flutter run --debug --flavor dev -t lib/main_dev.dart

docker exec -it brightbund-db psql -U user -d brightbund

cd tests && ./test_economy_cooldown.sh
# упадет при первой ошибке
set -e
DC="${DC:-docker compose exec -T db}"

echo "1. Копия базы app"
$DC pg_dump -U postgres -d app -Fc > backup.dump

echo "2. Чистая база app_restore"
$DC psql -U postgres -d postgres -c "DROP DATABASE IF EXISTS app_restore" -c "CREATE DATABASE app_restore"

echo "3. Восстановление копии"
$DC pg_restore -U postgres -d app_restore --no-owner < backup.dump

echo "4. Сравнение числа операций: app и app_restore"
$DC psql -U postgres -d app -tA -c "SELECT count(*) FROM operations"
$DC psql -U postgres -d app_restore -tA -c "SELECT count(*) FROM operations"

echo "5. Удаляем app_restore"
$DC psql -U postgres -d postgres -c "DROP DATABASE app_restore"
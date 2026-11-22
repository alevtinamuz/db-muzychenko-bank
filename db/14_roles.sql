\getenv reader_password APP_READER_PASSWORD
\getenv writer_password APP_WRITER_PASSWORD

-- app_reader только читает представления
CREATE ROLE app_reader LOGIN PASSWORD :'reader_password';
-- app_writer получает права app_reader
CREATE ROLE app_writer LOGIN PASSWORD :'writer_password' IN ROLE app_reader;
-- app_client без входа
CREATE ROLE app_client NOLOGIN;

-- По умолчанию функции может вызывать кто угодно, поэтому закрываем
REVOKE EXECUTE ON ALL ROUTINES IN SCHEMA public FROM PUBLIC;
-- Работает только через представления и функции
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC, app_reader, app_writer;

-- app_reader: только чтение представлений
GRANT SELECT ON v_account_card, v_client_summary, mv_monthly_report TO app_reader;

-- app_writer: только вызов бизнес-операций
ALTER FUNCTION make_operation(integer, operation_kind, numeric, integer, text)
    SECURITY DEFINER SET search_path = public, pg_temp;
ALTER FUNCTION transfer_money(integer, integer, numeric)
    SECURITY DEFINER SET search_path = public, pg_temp;
ALTER FUNCTION withdraw(integer, numeric, text)
    SECURITY DEFINER SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION make_operation(integer, operation_kind, numeric, integer, text) TO app_writer;
GRANT EXECUTE ON FUNCTION transfer_money(integer, integer, numeric) TO app_writer;
GRANT EXECUTE ON FUNCTION withdraw(integer, numeric, text) TO app_writer;
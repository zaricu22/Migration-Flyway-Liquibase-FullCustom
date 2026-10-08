-- Nobody writes old codes anymore. The mapping table stays as documentation
-- ("what did 'P' mean in 2019 reports?").
DROP TRIGGER orders_translate_status ON orders;
DROP FUNCTION orders_translate_status();

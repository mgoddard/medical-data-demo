CREATE ROLE demouser LOGIN PASSWORD 'demopasswd';
GRANT admin TO demouser; -- "demouser" can log into DB Console and also use defaultdb

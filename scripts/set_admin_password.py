from db_client import run_sql

sql = "UPDATE auth.users SET encrypted_password = crypt('Admin123456!', gen_salt('bf')) WHERE email = 'hana.ramadan@vsp.com';"
res = run_sql(sql)
print("Password updated for hana.ramadan@vsp.com:", res)

from db_client import run_sql

def cleanup():
    q = """
    DELETE FROM public.notifications WHERE body LIKE '%بطولة اختبار%' OR title LIKE '%بطولة اختبار%';
    DELETE FROM public.transactions WHERE championship_id IN (SELECT id FROM public.championships WHERE name LIKE 'بطولة اختبار%');
    DELETE FROM public.tournament_orders WHERE championship_id IN (SELECT id FROM public.championships WHERE name LIKE 'بطولة اختبار%');
    DELETE FROM public.teams WHERE name LIKE 'فريق الاختبار%';
    DELETE FROM public.championships WHERE name LIKE 'بطولة اختبار%';
    """
    run_sql(q)
    print("Test data cleaned up.")

if __name__ == "__main__":
    cleanup()

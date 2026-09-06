import subprocess
import json
import os

env = json.load(open('env.json'))
os_env = os.environ.copy()
os_env['SUPABASE_ACCESS_TOKEN'] = env['SUPABASE_MANAGEMENT_KEY']

proc = subprocess.run(['npx', 'supabase', 'functions', 'list', '--project-ref', 'mktqkddbcddrxjxabdua'], env=os_env, capture_output=True, text=True, shell=True)
print("Return code:", proc.returncode)
print("STDOUT:", proc.stdout)
print("STDERR:", proc.stderr)

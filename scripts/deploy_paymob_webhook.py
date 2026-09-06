import subprocess
import json
import os

env = json.load(open('env.json'))
os_env = os.environ.copy()
os_env['SUPABASE_ACCESS_TOKEN'] = env['SUPABASE_MANAGEMENT_KEY']

cmd = [
    'npx', 'supabase', 'functions', 'deploy', 'paymob_webhook',
    '--no-verify-jwt',
    '--project-ref', 'mktqkddbcddrxjxabdua'
]

print("Deploying paymob_webhook function...")
proc = subprocess.run(cmd, env=os_env, capture_output=True, text=True, shell=True)
print("Return code:", proc.returncode)
print("STDOUT:\n", proc.stdout)
print("STDERR:\n", proc.stderr)

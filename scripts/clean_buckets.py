import urllib.request, json

with open("env.json", "r") as f:
    env = json.load(f)

service_key = env["SUPABASE_SERVICE_ROLE_KEY"]
url_base = env["SUPABASE_URL"] + "/storage/v1/bucket"

# 1. Delete legacy orphaned bucket 'verification-documents'
del_url = f"{url_base}/verification-documents"
del_req = urllib.request.Request(del_url, headers={
    "apikey": service_key,
    "Authorization": f"Bearer {service_key}",
}, method="DELETE")
try:
    with urllib.request.urlopen(del_req) as resp:
        print("✅ Bucket 'verification-documents' deleted successfully!")
except Exception as e:
    print("Notice on deleting bucket:", e)

# 2. Update 'banners' bucket with size limit and mime types
banner_url = f"{url_base}/banners"
payload = json.dumps({
    "public": True,
    "file_size_limit": 10485760, # 10MB
    "allowed_mime_types": ["image/jpeg", "image/png", "image/webp"]
}).encode("utf-8")

put_req = urllib.request.Request(banner_url, data=payload, headers={
    "apikey": service_key,
    "Authorization": f"Bearer {service_key}",
    "Content-Type": "application/json",
}, method="PUT")
try:
    with urllib.request.urlopen(put_req) as resp:
        print("✅ Bucket 'banners' security hardened (10MB limit + image MIME types enforced)!")
except Exception as e:
    print("Notice on updating banners bucket:", e)

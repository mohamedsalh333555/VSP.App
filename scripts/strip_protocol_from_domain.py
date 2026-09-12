about_path = 'k:/.gemini/antigravity/scratch/vsp_website/src/app/about/page.tsx'
with open(about_path, 'r', encoding='utf-8') as f:
    about_content = f.read()

target_about = '<span className="font-bold text-white font-poppins">https://vspapp.online</span>'
replacement_about = '<span className="font-bold text-white font-poppins">vspapp.online</span>'

if target_about in about_content:
    about_content = about_content.replace(target_about, replacement_about)
    with open(about_path, 'w', encoding='utf-8') as f:
        f.write(about_content)
    print("Updated about/page.tsx successfully")
else:
    print("WARNING: target_about not found in about/page.tsx")

privacy_path = 'k:/.gemini/antigravity/scratch/vsp_website/src/app/privacy/page.tsx'
with open(privacy_path, 'r', encoding='utf-8') as f:
    privacy_content = f.read()

target_privacy_link = '<a href="https://vspapp.online" className="text-vsp-accent hover:underline font-poppins">https://vspapp.online</a>'
replacement_privacy_link = '<a href="https://vspapp.online" className="text-vsp-accent hover:underline font-poppins">vspapp.online</a>'

target_privacy_domain = '<span className="font-poppins text-white">https://vspapp.online</span>'
replacement_privacy_domain = '<span className="font-poppins text-white">vspapp.online</span>'

if target_privacy_link in privacy_content:
    privacy_content = privacy_content.replace(target_privacy_link, replacement_privacy_link)
    print("Replaced privacy links successfully")
else:
    print("WARNING: target_privacy_link not found")

if target_privacy_domain in privacy_content:
    privacy_content = privacy_content.replace(target_privacy_domain, replacement_privacy_domain)
    print("Replaced privacy domain successfully")
else:
    print("WARNING: target_privacy_domain not found")

with open(privacy_path, 'w', encoding='utf-8') as f:
    f.write(privacy_content)

print("All files updated successfully")

path = 'k:/.gemini/antigravity/scratch/vsp_website/src/components/layout/Footer.tsx'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update import
old_import = "import { PhoneIcon, WhatsAppIcon, LocationIcon } from '../ui/CustomIcons';"
new_import = "import { PhoneIcon, LocationIcon } from '../ui/CustomIcons';"

if old_import in content:
    content = content.replace(old_import, new_import)
    print("Updated import")
else:
    print("WARNING: old_import not found")

# 2. Update unused whatsapp variables
old_vars = """  const phone = settings?.support_phone || '+201100229462';
  const whatsapp = settings?.whatsapp_number || '+201100229462';
  const email = settings?.support_email || 'vspapp.eg@gmail.com';
  const whatsappUrl = `https://wa.me/${whatsapp.replace(/[^0-9]/g, '')}`;"""

new_vars = """  const phone = settings?.support_phone || '+201100229462';
  const email = settings?.support_email || 'vspapp.eg@gmail.com';"""

if old_vars in content:
    content = content.replace(old_vars, new_vars)
    print("Updated vars")
else:
    print("WARNING: old_vars not found")

# 3. Remove the first <li> item (the WhatsApp item)
old_list = """            <ul className="space-y-3 text-sm font-medium">
              <li>
                <a
                  href={whatsappUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-2.5 text-zinc-300 hover:text-vsp-accent transition-colors"
                >
                  <WhatsAppIcon className="w-4 h-4 text-vsp-status-success flex-shrink-0" size={16} />
                  <span dir="ltr" className="font-poppins">{whatsapp}</span>
                </a>
              </li>
              <li>
                <a
                  href={`tel:${phone}`}
                  className="flex items-center gap-2.5 text-zinc-300 hover:text-vsp-accent transition-colors"
                >
                  <PhoneIcon className="w-4 h-4 text-vsp-accent flex-shrink-0" size={16} />
                  <span dir="ltr" className="font-poppins">{phone}</span>
                </a>
              </li>"""

new_list = """            <ul className="space-y-3 text-sm font-medium">
              <li>
                <a
                  href={`tel:${phone}`}
                  className="flex items-center gap-2.5 text-zinc-300 hover:text-vsp-accent transition-colors"
                >
                  <PhoneIcon className="w-4 h-4 text-vsp-accent flex-shrink-0" size={16} />
                  <span dir="ltr" className="font-poppins">{phone}</span>
                </a>
              </li>"""

if old_list in content:
    content = content.replace(old_list, new_list)
    print("Removed first contact item (WhatsApp)")
else:
    print("WARNING: old_list not found")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Footer.tsx updated successfully")

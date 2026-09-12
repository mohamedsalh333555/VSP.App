about_path = 'k:/.gemini/antigravity/scratch/vsp_website/src/app/about/page.tsx'
with open(about_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Expand container from max-w-4xl to max-w-5xl
old_container = '<div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">'
new_container = '<div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">'

if old_container in content:
    content = content.replace(old_container, new_container)
    print("Expanded container width to max-w-5xl")
else:
    print("WARNING: old_container not found")

# 2. Update the Pillars Grid
old_pillars = """          {/* Pillars Grid */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 pt-2">
            <div className="p-5 rounded-2xl bg-zinc-900/90 border border-zinc-800 space-y-3">
              <div className="w-10 h-10 rounded-xl bg-vsp-accent/15 border border-vsp-accent/40 flex items-center justify-center text-vsp-accent font-black">
                1
              </div>
              <h3 className="text-base font-bold text-white font-tajawal">
                {isAr ? 'حجز ذري بدون تعارض' : 'Zero-Conflict Atomic Booking'}
              </h3>
              <p className="text-xs text-zinc-400 leading-relaxed font-tajawal">
                {isAr
                  ? 'نظام حجز لحظي يقفل الفترة الزمنية في أجزاء من الثانية ويمنع الحجز المزدوج نهائياً، مع تأكيد فوري عبر إشعار ورمز تحقق رقمي.'
                  : 'Instant reservation system that locks match slots in milliseconds, completely preventing double bookings with immediate digital verification.'}
              </p>
            </div>

            <div className="p-5 rounded-2xl bg-zinc-900/90 border border-zinc-800 space-y-3">
              <div className="w-10 h-10 rounded-xl bg-vsp-accent/15 border border-vsp-accent/40 flex items-center justify-center text-vsp-accent font-black">
                2
              </div>
              <h3 className="text-base font-bold text-white font-tajawal">
                {isAr ? 'البطولات الرسمية' : 'Official Tournaments'}
              </h3>
              <p className="text-xs text-zinc-400 leading-relaxed font-tajawal">
                {isAr
                  ? 'بطولات كروية تنافسية بالكامل على أساس المهارة والأداء الرياضي. رسوم الاشتراك تُستخدم حصرياً لتغطية تكاليف تنظيم البطولة (حجز الملاعب، التحكيم، الجدولة). الجوائز والكؤوس مقدَّمة من VSP والجهات الراعية للبطولة، وليست ممولة من رسوم اشتراك الفرق المتنافسة.'
                  : 'Purely skill-based competitive football tournaments. Entry fees are exclusively used to cover organizational costs (pitches, referees, scheduling). Trophies and awards are sponsored by VSP and official partners, never funded from participating team fees.'}
              </p>
            </div>

            <div className="p-5 rounded-2xl bg-zinc-900/90 border border-zinc-800 space-y-3">
              <div className="w-10 h-10 rounded-xl bg-vsp-accent/15 border border-vsp-accent/40 flex items-center justify-center text-vsp-accent font-black">
                3
              </div>
              <h3 className="text-base font-bold text-white font-tajawal">
                {isAr ? 'حلول متكاملة للمنشآت' : 'Facility Management Solutions'}
              </h3>
              <p className="text-xs text-zinc-400 leading-relaxed font-tajawal">
                {isAr
                  ? 'لوحة تحكم ذكية لملاك الملاعب لإدارة الشيفتات والحسابات اليومية والحد من غياب اللاعبين وزيادة نسبة الإشغال بنسبة 25%.'
                  : 'Smart operations dashboard for pitch owners to manage shifts, daily ledgers, prevent no-shows, and boost facility occupancy by 25%.'}
              </p>
            </div>
          </div>"""

new_pillars = """          {/* Pillars Grid */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 pt-2 items-stretch">
            <div className="p-5 rounded-2xl bg-zinc-900/90 border border-zinc-800 space-y-3 flex flex-col h-full">
              <div className="w-10 h-10 rounded-xl bg-vsp-accent/15 border border-vsp-accent/40 flex items-center justify-center text-vsp-accent font-black flex-shrink-0">
                1
              </div>
              <h3 className="text-base font-bold text-white font-tajawal">
                {isAr ? 'حجز ذري بدون تعارض' : 'Zero-Conflict Atomic Booking'}
              </h3>
              <p className="text-xs text-zinc-400 leading-relaxed font-tajawal flex-grow">
                {isAr
                  ? 'نظام حجز لحظي يقفل الفترة الزمنية في أجزاء من الثانية ويمنع الحجز المزدوج نهائياً، مع تأكيد فوري عبر إشعار ورمز تحقق رقمي.'
                  : 'Instant reservation system that locks match slots in milliseconds, completely preventing double bookings with immediate digital verification.'}
              </p>
            </div>

            <div className="p-5 rounded-2xl bg-zinc-900/90 border border-zinc-800 space-y-3 flex flex-col h-full">
              <div className="w-10 h-10 rounded-xl bg-vsp-accent/15 border border-vsp-accent/40 flex items-center justify-center text-vsp-accent font-black flex-shrink-0">
                2
              </div>
              <h3 className="text-base font-bold text-white font-tajawal">
                {isAr ? 'البطولات الرسمية' : 'Official Tournaments'}
              </h3>
              <p className="text-xs text-zinc-400 leading-relaxed font-tajawal flex-grow">
                {isAr
                  ? 'بطولات كروية تنافسية على أساس المهارة الرياضية؛ رسوم الاشتراك مخصصة لتكاليف التنظيم فقط، والجوائز والكؤوس برعاية VSP والشركاء دون أي مراهنات.'
                  : 'Purely skill-based competitive football tournaments; entry fees cover organizational costs only, with awards fully sponsored by VSP and official partners without any wagering.'}
              </p>
            </div>

            <div className="p-5 rounded-2xl bg-zinc-900/90 border border-zinc-800 space-y-3 flex flex-col h-full">
              <div className="w-10 h-10 rounded-xl bg-vsp-accent/15 border border-vsp-accent/40 flex items-center justify-center text-vsp-accent font-black flex-shrink-0">
                3
              </div>
              <h3 className="text-base font-bold text-white font-tajawal">
                {isAr ? 'حلول متكاملة للمنشآت' : 'Facility Management Solutions'}
              </h3>
              <p className="text-xs text-zinc-400 leading-relaxed font-tajawal flex-grow">
                {isAr
                  ? 'لوحة تحكم ذكية لملاك الملاعب لإدارة الشيفتات والحسابات اليومية والحد من غياب اللاعبين وزيادة نسبة الإشغال بنسبة 25%.'
                  : 'Smart operations dashboard for pitch owners to manage shifts, daily ledgers, prevent no-shows, and boost facility occupancy by 25%.'}
              </p>
            </div>
          </div>"""

if old_pillars in content:
    content = content.replace(old_pillars, new_pillars)
    print("Replaced pillars successfully")
else:
    print("WARNING: old_pillars not found")

with open(about_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("about/page.tsx updated successfully")

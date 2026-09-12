import sys

path = 'k:/.gemini/antigravity/scratch/vsp_website/src/components/sections/LiveStadiumsSection.tsx'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_badge = '''          <div className="text-xs font-bold text-zinc-400 bg-[#141615] px-4 py-2 rounded-full border border-zinc-800 w-fit">
            {language === 'ar'
              ? `${filteredStadiums.length} ملعب متاح الآن`
              : `${filteredStadiums.length} Pitches Available`}
          </div>'''

new_badge = '''          <div className="text-xs font-bold text-zinc-400 bg-[#141615] px-4 py-2 rounded-full border border-zinc-800 w-fit">
            {initialStadiums.length > 0
              ? (language === 'ar'
                  ? `${filteredStadiums.length} ملعب متاح الآن`
                  : `${filteredStadiums.length} Pitches Available`)
              : (language === 'ar'
                  ? 'اعتماد وتوثيق الملاعب جارٍ 🛡️'
                  : 'Venue Certification in Progress 🛡️')}
          </div>'''

old_filter = '''        {/* ── Dynamic Filter Bar ── */}
        <div className="p-4 sm:p-5 rounded-2xl sm:rounded-3xl bg-[#111312] border border-zinc-800/90 backdrop-blur-xl mb-8 sm:mb-10 flex flex-col md:flex-row md:items-center justify-between gap-4 sm:gap-6 shadow-xl">'''

new_filter = '''        {/* ── Dynamic Filter Bar (Shown only when stadiums are loaded) ── */}
        {initialStadiums.length > 0 && (
          <div className="p-4 sm:p-5 rounded-2xl sm:rounded-3xl bg-[#111312] border border-zinc-800/90 backdrop-blur-xl mb-8 sm:mb-10 flex flex-col md:flex-row md:items-center justify-between gap-4 sm:gap-6 shadow-xl">'''

old_filter_end = '''              aria-label={t('stadium_filter_price_aria')}
            />
          </div>
        </div>

        {/* Stadiums Grid or Empty State */}'''

new_filter_end = '''              aria-label={t('stadium_filter_price_aria')}
            />
          </div>
        </div>
        )}

        {/* Stadiums Grid or Empty State */}'''

old_empty = '''        {/* Stadiums Grid or Empty State */}
        {filteredStadiums.length === 0 ? (
          <EmptyState
            icon={<StadiumIcon className="w-8 h-8 text-zinc-400" size={32} />}
            title={t('stadiums_empty_title')}
            subtitle={t('stadiums_empty_subtitle')}
            actionText={t('stadiums_empty_action')}
            onAction={() => {
              setSelectedCity('all');
              setMaxPrice(1000);
            }}
          />'''

new_empty = '''        {/* Stadiums Grid or Empty State */}
        {filteredStadiums.length === 0 ? (
          <EmptyState
            icon={<StadiumIcon className="w-8 h-8 text-zinc-400" size={32} />}
            title={
              initialStadiums.length === 0
                ? (language === 'ar' ? 'الملاعب المعتمدة تنطلق قريباً' : 'Certified Venues Launching Soon')
                : t('stadiums_empty_title')
            }
            subtitle={
              initialStadiums.length === 0
                ? (language === 'ar'
                    ? 'تجري منصة VSP حالياً عمليات الفحص الميداني وتوثيق الملاعب الرياضية في أسوان ومصر لإتاحة الحجز اللحظي الموثق 100% عبر التطبيق.'
                    : 'VSP is currently conducting on-site verification and quality checks for sports venues across Aswan and Egypt to enable 100% verified instant bookings.')
                : t('stadiums_empty_subtitle')
            }
            actionText={
              initialStadiums.length === 0
                ? (language === 'ar' ? 'انضم كصاحب ملعب معتمد' : 'Register Your Venue')
                : t('stadiums_empty_action')
            }
            onAction={() => {
              if (initialStadiums.length === 0) {
                const el = document.getElementById('owners');
                el?.scrollIntoView({ behavior: 'smooth' });
              } else {
                setSelectedCity('all');
                setMaxPrice(1000);
              }
            }}
          />'''

if old_badge in content:
    content = content.replace(old_badge, new_badge)
    print("Replaced badge successfully")
else:
    print("WARNING: old_badge not found")

if old_filter in content:
    content = content.replace(old_filter, new_filter)
    print("Replaced filter successfully")
else:
    print("WARNING: old_filter not found")

if old_filter_end in content:
    content = content.replace(old_filter_end, new_filter_end)
    print("Replaced filter_end successfully")
else:
    print("WARNING: old_filter_end not found")

if old_empty in content:
    content = content.replace(old_empty, new_empty)
    print("Replaced empty successfully")
else:
    print("WARNING: old_empty not found")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("FILE SAVED SUCCESSFULLY")

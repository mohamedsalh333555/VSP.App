import re

page_path = r'K:\.gemini\antigravity\scratch\vsp_admin_panel\src\pages\League1v1Page.jsx'
with open(page_path, 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Update imports
target_import = "} from 'lucide-react';"
replacement_import = """  MapPin,
  Filter
} from 'lucide-react';

export const EGYPT_GOVERNORATES = [
  { id: 'Cairo', name: 'القاهرة' },
  { id: 'Giza', name: 'الجيزة' },
  { id: 'Alexandria', name: 'الإسكندرية' },
  { id: 'Dakahlia', name: 'الدقهلية' },
  { id: 'Sharqia', name: 'الشرقية' },
  { id: 'Monufia', name: 'المنوفية' },
  { id: 'Qalyubia', name: 'القليوبية' },
  { id: 'Gharbia', name: 'الغربية' },
  { id: 'Beheira', name: 'البحيرة' },
  { id: 'Damietta', name: 'دمياط' },
  { id: 'Port Said', name: 'بورسعيد' },
  { id: 'Ismailia', name: 'الإسماعيلية' },
  { id: 'Suez', name: 'السويس' },
  { id: 'Kafr El Sheikh', name: 'كفر الشيخ' },
  { id: 'Faiyum', name: 'الفيوم' },
  { id: 'Beni Suef', name: 'بني سويف' },
  { id: 'Minya', name: 'المنيا' },
  { id: 'Asyut', name: 'أسيوط' },
  { id: 'Sohag', name: 'سوهاج' },
  { id: 'Qena', name: 'قنا' },
  { id: 'Luxor', name: 'الأقصر' },
  { id: 'Aswan', name: 'أسوان' },
  { id: 'Red Sea', name: 'البحر الأحمر' },
  { id: 'New Valley', name: 'الوادي الجديد' },
  { id: 'Matrouh', name: 'مطروح' },
  { id: 'North Sinai', name: 'شمال سيناء' },
  { id: 'South Sinai', name: 'جنوب سيناء' },
];

export const getGovArabicName = (govKey) => {
  if (!govKey) return '-';
  const found = EGYPT_GOVERNORATES.find(
    (g) => g.id.toLowerCase() === (govKey || '').toLowerCase()
  );
  return found ? found.name : govKey;
};"""

assert target_import in text, 'target_import not found'
text = text.replace(target_import, replacement_import, 1)

# 2. Add state
target_state = "// Active Tournament State\n const [activeTournament, setActiveTournament] = useState(null);"
replacement_state = """// Governorate Scoping State
 const [selectedGovernorate, setSelectedGovernorate] = useState('Cairo');
 const [allActiveTournaments, setAllActiveTournaments] = useState([]);
 const [selectedGovInput, setSelectedGovInput] = useState('Cairo');
 const [historyGovFilter, setHistoryGovFilter] = useState('all');

 // Active Tournament State
 const [activeTournament, setActiveTournament] = useState(null);"""

assert target_state in text, 'target_state not found'
text = text.replace(target_state, replacement_state, 1)

# 3. Replace loadData
idx_ld1 = text.find("const loadData = async () => {")
idx_ld2 = text.find("useEffect(() => {", idx_ld1)
assert idx_ld1 != -1 and idx_ld2 != -1, 'loadData bounds not found'

replacement_load = """const loadData = async (targetGov = null) => {
  try {
   setLoading(true);
   const govToUse = targetGov !== null ? targetGov : selectedGovernorate;

   // 1. Fetch all active tournaments across governorates
   const activeRes = await adminService.listActive1v1Tournaments();
   const activeList = activeRes.success ? (activeRes.tournaments || []) : [];
   setAllActiveTournaments(activeList);

   // 2. Fetch current active or latest tournament for the selected governorate
   const res = await adminService.getActiveOrLatest1v1Tournament(govToUse);
   if (res.success) {
    setActiveTournament(res.tournament);
    setPlayers(res.players || []);
   } else {
    setActiveTournament(null);
    setPlayers([]);
   }

   // 3. Fetch history list
   const histRes = await adminService.list1v1Tournaments();
   if (histRes.success) {
    setHistoryList(histRes.tournaments || []);
   }

   // 4. Fetch registrations
   const regRes = await adminService.fetch1v1PendingRegistrations();
   if (regRes.success) {
    setRegistrations(regRes.data || []);
   }
  } catch (e) {
   console.error('Error loading 1v1 data:', e);
   setAlert({ type: 'error', message: 'حدث خطأ أثناء تحميل البيانات: ' + e.message });
  } finally {
   setLoading(false);
  }
 };

 const handleGovernorateChange = (gov) => {
  setSelectedGovernorate(gov);
  loadData(gov);
 };

 """

text = text[:idx_ld1] + replacement_load + text[idx_ld2:]

# 4. Replace handleOpenNewTournamentModal & handleConfirmStartTournament
idx_sm1 = text.find("const handleOpenNewTournamentModal = () => {")
idx_sm2 = text.find("// -------------------------------------------------------------------------\n // 2. LIVE SCORING SHEET ROW ACTIONS", idx_sm1)
assert idx_sm1 != -1 and idx_sm2 != -1, 'start modal handler bounds not found'

replacement_start = """const handleOpenNewTournamentModal = (initialGov = null) => {
  const gov = initialGov || selectedGovernorate || 'Cairo';
  const today = new Date().toLocaleDateString('ar-EG', {
   weekday: 'long',
   year: 'numeric',
   month: 'short',
   day: 'numeric',
  });
  setTournamentName(`بطولة 1vs1 فردية - ${getGovArabicName(gov)} - ${today}`);
  setSelectedGovInput(gov);
  setPlayerCountInput('8');
  setShowNewModal(true);
 };

 const handleConfirmStartTournament = async (e) => {
  e.preventDefault();
  const count = parseInt(playerCountInput);
  if (!count || count < 2) {
   setAlert({ type: 'error', message: 'يرجى إدخال عدد لاعبين صحيح (لا يقل عن 2).' });
   return;
  }

  try {
   setProcessing(true);

   // Get current logged-in admin user ID if available
   const { data: authData } = await supabase.auth.getUser();
   const adminUserId = authData?.user?.id || null;

   // Create new registration_open tournament
   const scheduledIso = scheduledAtInput ? new Date(scheduledAtInput).toISOString() : null;
   const fee = parseFloat(entryFeeInput) || 0;
   const createRes = await adminService.create1v1Tournament({
    name: tournamentName,
    target_player_count: count,
    entry_fee: fee,
    scheduled_at: scheduledIso,
    created_by: adminUserId,
    governorate: selectedGovInput || 'Cairo',
   });

   if (!createRes.success) {
    throw new Error(createRes.error || 'فشل إنشاء البطولة');
   }

   const newTournament = createRes.data;

   setSelectedGovernorate(newTournament.governorate);
   setActiveTournament(newTournament);
   setPlayers([]);
   setShowNewModal(false);
   setAlert({
    type: 'success',
    message: `تم إنشاء البطولة لمحافظة ${getGovArabicName(newTournament.governorate)} وفتح باب التسجيل بنجاح!`,
   });

   await loadData(newTournament.governorate);
  } catch (e) {
   console.error('Error starting new tournament:', e);
   setAlert({ type: 'error', message: e.message || 'فشل بدء البطولة' });
  } finally {
   setProcessing(false);
  }
 };

 """

text = text[:idx_sm1] + replacement_start + text[idx_sm2:]

# 5. Add governorate select to showNewModal form
m_form = re.search(r'<div>\s*<label[^>]*>\s*اسم / عنوان البطولة\s*</label>', text)
assert m_form, 'modal form name label not found'
gov_select_code = """<div>
 <label className="block text-xs font-bold text-zinc-300 mb-1.5 flex items-center gap-1.5">
  <MapPin className="w-3.5 h-3.5 text-amber-400" />
  <span>المحافظة المستهدفة للبطولة</span>
 </label>
 <select
  value={selectedGovInput}
  onChange={(e) => {
   const newGov = e.target.value;
   setSelectedGovInput(newGov);
   const today = new Date().toLocaleDateString('ar-EG', {
    weekday: 'long',
    year: 'numeric',
    month: 'short',
    day: 'numeric',
   });
   setTournamentName(`بطولة 1vs1 فردية - ${getGovArabicName(newGov)} - ${today}`);
  }}
  className="w-full bg-vsp-card border border-vsp-border rounded-xl px-4 py-2.5 text-white font-bold text-xs focus:border-vsp-accent focus:outline-none"
  required
 >
  {EGYPT_GOVERNORATES.map((g) => (
   <option key={g.id} value={g.id} className="bg-zinc-900 text-white">
    {g.name} ({g.id})
   </option>
  ))}
 </select>
 <span className="text-[11px] text-zinc-400 mt-1 block">
  ستكون هذه البطولة مخصصة وحصرية للاعبي هذه المحافظة على تطبيق الموبايل.
 </span>
 </div>

 """
text = text[:m_form.start()] + gov_select_code + text[m_form.start():]

# 6. Update TAB 1 header with Governorate bar and governorate badge
idx_live1 = text.find("{/* TAB 1: LIVE BULK SCORING SHEET */}")
idx_live2 = text.find("{/* Bulk Save & Publish Controls */}", idx_live1)
assert idx_live1 != -1 and idx_live2 != -1, 'live tab bounds not found'

replacement_live_tab_head = """{/* TAB 1: LIVE BULK SCORING SHEET */}
 {/* ==================================================================== */}
 {activeTab === 'live' && (
 <div className="space-y-6">
  {/* Governorate Selection Bar */}
  <div className="bg-vsp-surface border border-vsp-border rounded-2xl p-4 shadow-lg flex flex-col md:flex-row md:items-center justify-between gap-4">
   <div className="flex items-center gap-3">
    <div className="p-2 bg-amber-500/10 border border-amber-500/30 rounded-xl text-amber-400">
     <MapPin className="w-5 h-5" />
    </div>
    <div>
     <span className="text-xs font-bold text-vsp-textSecondary block">المحافظة الحالية للرصد:</span>
     <span className="text-base font-black text-white">{getGovArabicName(selectedGovernorate)}</span>
    </div>
   </div>

   <div className="flex flex-wrap items-center gap-2">
    <span className="text-xs font-bold text-zinc-400">تغيير المحافظة:</span>
    <select
     value={selectedGovernorate}
     onChange={(e) => handleGovernorateChange(e.target.value)}
     disabled={loading || processing}
     className="bg-vsp-card border border-vsp-border rounded-xl px-3 py-2 text-xs font-bold text-white focus:border-vsp-accent focus:outline-none"
    >
     {EGYPT_GOVERNORATES.map((g) => {
      const hasActive = allActiveTournaments.some((t) => t.governorate?.toLowerCase() === g.id.toLowerCase());
      return (
       <option key={g.id} value={g.id} className="bg-zinc-900 text-white">
        {g.name} {hasActive ? '• (بطولة نشطة)' : ''}
       </option>
      );
     })}
    </select>

    {allActiveTournaments.length > 0 && (
     <div className="flex items-center gap-1.5 mr-2">
      <span className="text-[11px] text-zinc-500">نشطة الآن:</span>
      {allActiveTournaments.map((t) => (
       <button
        key={t.id}
        type="button"
        onClick={() => handleGovernorateChange(t.governorate)}
        className={`px-2.5 py-1 rounded-lg text-xs font-bold border transition-all ${
         selectedGovernorate?.toLowerCase() === t.governorate?.toLowerCase()
          ? 'bg-amber-500/20 border-amber-500/40 text-amber-300'
          : 'bg-vsp-card border-vsp-border text-zinc-400 hover:text-white'
        }`}
       >
        {getGovArabicName(t.governorate)}
       </button>
      ))}
     </div>
    )}
   </div>
  </div>

  {loading ? (
   <div className="p-16 flex flex-col items-center justify-center gap-3 bg-vsp-surface border border-vsp-border rounded-2xl">
    <Loader2 className="w-8 h-8 text-vsp-accent animate-spin" />
    <span className="text-xs text-vsp-textSecondary font-bold">جاري تحميل بيانات البطولة...</span>
   </div>
  ) : !activeTournament ? (
   <div className="bg-vsp-surface border border-vsp-border rounded-2xl p-10 text-center space-y-4">
    <div className="w-14 h-14 mx-auto rounded-2xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400">
     <Trophy className="w-7 h-7" />
    </div>
    <div>
     <h3 className="text-lg font-bold text-white">لا توجد بطولة نشطة حالياً في محافظة {getGovArabicName(selectedGovernorate)}</h3>
     <p className="text-xs text-vsp-textSecondary mt-1 max-w-md mx-auto">
      يمكنك بدء بطولة جديدة خاصة بمحافظة {getGovArabicName(selectedGovernorate)} الآن، أو التبديل لمحافظة أخرى من القائمة بالأعلى.
     </p>
    </div>
    <button
     onClick={() => handleOpenNewTournamentModal(selectedGovernorate)}
     className="inline-flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-amber-500 to-amber-600 hover:from-amber-400 hover:to-amber-500 text-black font-black text-xs rounded-xl shadow-lg shadow-amber-500/20 transition-all active:scale-95"
    >
     <Plus className="w-4 h-4 stroke-[3]" />
     <span>بدء بطولة جديدة في {getGovArabicName(selectedGovernorate)}</span>
    </button>
   </div>
  ) : (
   <>
    {/* Active Tournament Status Card */}
    <div className="bg-vsp-surface border border-vsp-border rounded-2xl p-5 shadow-lg flex flex-col md:flex-row md:items-center justify-between gap-4">
     <div>
      <div className="flex items-center gap-3 flex-wrap">
       <h2 className="text-lg font-black text-white">{activeTournament.name}</h2>
       <span className="px-2.5 py-1 rounded-xl text-xs font-bold bg-amber-500/15 text-amber-300 border border-amber-500/30 flex items-center gap-1">
        <MapPin className="w-3.5 h-3.5" />
        {getGovArabicName(activeTournament.governorate)}
       </span>
       {activeTournament.status === 'published' ? (
        <Badge variant="accent" size="sm">
         منشورة على التطبيق مباشرة 
        </Badge>
       ) : activeTournament.status === 'draft' ? (
        <Badge variant="warning" size="sm">
         مسودة قيد الإدخال (Draft) 
        </Badge>
       ) : (
        <Badge variant="default" size="sm">
         مؤرشفة (Archived) 
        </Badge>
       )}
      </div>
      <div className="flex items-center gap-4 text-xs text-zinc-400 mt-2">
       <span>
        عدد اللاعبين المستهدف:{' '}
        <strong className="text-white">{activeTournament.target_player_count || players.length}</strong>
       </span>
       <span>•</span>
       <span>
        تم الإنشاء:{' '}
        <strong className="text-white">
         {new Date(activeTournament.created_at).toLocaleDateString('ar-EG')}
        </strong>
       </span>
       {activeTournament.published_at && (
        <>
         <span>•</span>
         <span>
          نُشرت في:{' '}
          <strong className="text-emerald-400">
           {new Date(activeTournament.published_at).toLocaleTimeString('ar-EG', {
            hour: '2-digit',
            minute: '2-digit',
           })}
          </strong>
         </span>
        </>
       )}
      </div>
     </div>

     """

text = text[:idx_live1] + replacement_live_tab_head + text[idx_live2:]

# 7. Update History Tab with filter and governorate column
idx_h1 = text.find("{activeTab === 'history' && (")
idx_h2 = text.find("{activeTab === 'registrations' && (", idx_h1)
assert idx_h1 != -1 and idx_h2 != -1, 'history tab bounds not found'

replacement_history_tab = """{activeTab === 'history' && (
 <div className="bg-vsp-surface border border-vsp-border rounded-2xl overflow-hidden shadow-xl">
  {/* History Governorate Filter */}
  <div className="p-4 bg-vsp-card/40 border-b border-vsp-border flex items-center justify-between gap-4">
   <div className="flex items-center gap-2">
    <Filter className="w-4 h-4 text-zinc-400" />
    <span className="text-xs font-bold text-zinc-300">تصفية الأرشيف حسب المحافظة:</span>
   </div>
   <select
    value={historyGovFilter}
    onChange={(e) => setHistoryGovFilter(e.target.value)}
    className="bg-vsp-card border border-vsp-border rounded-xl px-3 py-1.5 text-xs font-bold text-white focus:border-vsp-accent focus:outline-none"
   >
    <option value="all">جميع المحافظات ({historyList.length})</option>
    {EGYPT_GOVERNORATES.map((g) => {
     const count = historyList.filter((t) => t.governorate?.toLowerCase() === g.id.toLowerCase()).length;
     if (count === 0) return null;
     return (
      <option key={g.id} value={g.id} className="bg-zinc-900 text-white">
       {g.name} ({count})
      </option>
     );
    })}
   </select>
  </div>

  {historyList.length === 0 ? (
   <EmptyState
    icon={History}
    title="لا توجد بطولات سابقة في الأرشيف"
    subtitle="عندما تقوم بنشر نسخ جديدة من البطولة، سيتم الاحتفاظ بالنسخ السابقة هنا كأرشيف دائم."
   />
  ) : (
   <div className="overflow-x-auto">
    <table className="w-full text-right text-xs">
     <thead className="bg-vsp-card/60 text-vsp-textSecondary border-b border-vsp-border">
      <tr>
       <th className="px-6 py-4 font-bold">اسم البطولة</th>
       <th className="px-6 py-4 font-bold">المحافظة</th>
       <th className="px-6 py-4 font-bold text-center">الحالة</th>
       <th className="px-6 py-4 font-bold text-center">العدد المستهدف</th>
       <th className="px-6 py-4 font-bold">تاريخ الإنشاء</th>
       <th className="px-6 py-4 font-bold">تاريخ النشر</th>
       <th className="px-6 py-4 font-bold text-center">الإجراءات</th>
      </tr>
     </thead>
     <tbody className="divide-y divide-vsp-border/50">
      {historyList
       .filter((item) => historyGovFilter === 'all' || item.governorate?.toLowerCase() === historyGovFilter.toLowerCase())
       .map((item) => (
       <tr key={item.id} className="hover:bg-vsp-card/30 transition-colors">
        <td className="px-6 py-4 font-bold text-white">{item.name}</td>
        <td className="px-6 py-4 font-bold text-zinc-300">
         <span className="px-2.5 py-1 bg-vsp-card border border-vsp-border rounded-lg text-xs flex items-center gap-1 w-fit">
          <MapPin className="w-3 h-3 text-amber-400" />
          {getGovArabicName(item.governorate)}
         </span>
        </td>
        <td className="px-6 py-4 text-center">
         {item.status === 'published' ? (
          <Badge variant="accent" size="xs">
           منشورة حالياً 
          </Badge>
         ) : item.status === 'draft' ? (
          <Badge variant="warning" size="xs">
           مسودة 
          </Badge>
         ) : (
          <Badge variant="default" size="xs">
           مؤرشفة 
          </Badge>
         )}
        </td>
        <td className="px-6 py-4 text-center font-bold text-zinc-300">
         {item.target_player_count} لاعبين
        </td>
        <td className="px-6 py-4 text-zinc-400 font-mono">
         {new Date(item.created_at).toLocaleDateString('ar-EG')}
        </td>
        <td className="px-6 py-4 text-zinc-400 font-mono">
         {item.published_at ? new Date(item.published_at).toLocaleDateString('ar-EG') : '-'}
        </td>
        <td className="px-6 py-4 text-center">
         <button
          onClick={() => handleViewArchive(item)}
          className="flex items-center gap-1 px-3 py-1.5 bg-vsp-card hover:bg-vsp-border border border-vsp-border text-white rounded-lg text-xs font-bold transition-all mx-auto"
         >
          <Eye className="w-3.5 h-3.5 text-zinc-400" />
          <span>عرض التفاصيل</span>
         </button>
        </td>
       </tr>
      ))}
     </tbody>
    </table>
   </div>
  )}
 </div>
 )}

 """

text = text[:idx_h1] + replacement_history_tab + text[idx_h2:]

with open(page_path, 'w', encoding='utf-8') as f:
    f.write(text)

print('SUCCESS: League1v1Page.jsx patched cleanly with Governorate Scoping!')

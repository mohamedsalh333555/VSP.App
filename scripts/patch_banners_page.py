import sys

path = r'k:\.gemini\antigravity\scratch\vsp_admin_panel\src\pages\BannersManagementPage.jsx'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add loadError state
target_state = "const [banners, setBanners] = useState([]);"
if "const [loadError, setLoadError] = useState(null);" not in content:
    content = content.replace(target_state, target_state + "\n  const [loadError, setLoadError] = useState(null);")

# 2. Update loadData
old_load_data = """  const loadData = async () => {
    setLoading(true);
    try {
      const [bannersRes, statsRes] = await Promise.all([
        bannersService.fetchBanners({ placement: filterPlacement, status: filterStatus }),
        bannersService.fetchBannerStats(),
      ]);

      if (bannersRes.success) {
        setBanners(bannersRes.data || []);
      } else {
        showToast(bannersRes.error || t('error_loading'), 'error');
      }

      if (statsRes.success) {
        setStats(statsRes.stats);
      }
    } catch (e) {
      showToast(e.message || t('error_loading'), 'error');
    } finally {
      setLoading(false);
    }
  };"""

new_load_data = """  const loadData = async () => {
    setLoading(true);
    setLoadError(null);
    try {
      const [bannersRes, statsRes] = await Promise.all([
        bannersService.fetchBanners({ placement: filterPlacement, status: filterStatus }),
        bannersService.fetchBannerStats(),
      ]);

      if (bannersRes.success) {
        setBanners(bannersRes.data || []);
      } else {
        setLoadError(bannersRes.error || 'تعذر تحميل بيانات البانرات، يرجى المحاولة مرة أخرى');
        showToast(bannersRes.error || t('error_loading'), 'error');
      }

      if (statsRes.success) {
        setStats(statsRes.stats);
      }
    } catch (e) {
      setLoadError(e.message || 'تعذر تحميل بيانات البانرات، يرجى المحاولة مرة أخرى');
      showToast(e.message || t('error_loading'), 'error');
    } finally {
      setLoading(false);
    }
  };"""

content = content.replace(old_load_data, new_load_data)

# 3. Update render
old_render = """      {loading ? (
        <div className="p-16 flex flex-col items-center justify-center gap-3 bg-vsp-surface border border-vsp-border rounded-2xl">
          <Loader2 className="w-8 h-8 text-vsp-accent animate-spin" />
          <span className="text-xs text-vsp-textSecondary">{t('loading')}</span>
        </div>
      ) : filteredBanners.length === 0 ? ("""

new_render = """      {loading ? (
        <div className="p-16 flex flex-col items-center justify-center gap-3 bg-vsp-surface border border-vsp-border rounded-2xl">
          <Loader2 className="w-8 h-8 text-vsp-accent animate-spin" />
          <span className="text-xs text-vsp-textSecondary">{t('loading')}</span>
        </div>
      ) : loadError ? (
        <div className="bg-vsp-surface border border-vsp-border rounded-2xl p-8">
          <EmptyState
            isError={true}
            title="فشل تحميل البيانات"
            description={loadError}
            actionLabel="إعادة المحاولة"
            actionIcon={RefreshCw}
            onAction={loadData}
          />
        </div>
      ) : filteredBanners.length === 0 ? ("""

content = content.replace(old_render, new_render)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated BannersManagementPage.jsx successfully')

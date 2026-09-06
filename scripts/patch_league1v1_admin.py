import os

path = r'K:\.gemini\antigravity\scratch\vsp_admin_panel\src\pages\League1v1Page.jsx'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# Add handleToggleStatus function
toggle_func = '''  const handleToggleStatus = async (newStatus) => {
    if (!activeTournament?.id) return;
    try {
      setProcessing(true);
      const res = await adminService.update1v1TournamentStatus(activeTournament.id, newStatus);
      if (!res.success) throw new Error(res.error || 'فشل تغيير الحالة');
      setActiveTournament((prev) => ({ ...prev, status: newStatus }));
      setAlert({
        type: 'success',
        message: newStatus === 'in_progress' 
          ? 'تم إغلاق باب التسجيل وبدء مرحلة رصد الدرجات! ⏱️' 
          : 'تم إعادة فتح باب التسجيل للاعبين عبر الموبايل! 🟢',
      });
      loadData();
    } catch (e) {
      setAlert({ type: 'error', message: e.message });
    } finally {
      setProcessing(false);
    }
  };

  // -------------------------------------------------------------------------
  // 3. SAVE DRAFT'''

if 'const handleToggleStatus =' not in text:
    text = text.replace('  // -------------------------------------------------------------------------\n  // 3. SAVE DRAFT', toggle_func)

# Add toggle button in Bulk Save & Publish Controls
old_controls = '''                {/* Bulk Save & Publish Controls */}
                <div className="flex items-center gap-3">
                  <button
                    onClick={handleSaveDraft}'''

new_controls = '''                {/* Bulk Save & Publish Controls */}
                <div className="flex items-center gap-3">
                  {activeTournament.status === 'registration_open' && (
                    <button
                      onClick={() => handleToggleStatus('in_progress')}
                      disabled={processing}
                      className="flex items-center gap-2 px-4 py-2.5 bg-amber-500/15 hover:bg-amber-500/25 border border-amber-500/30 text-amber-300 text-xs font-bold rounded-xl transition-all"
                    >
                      <span>إغلاق التسجيل وبدء الرصد ⏱️</span>
                    </button>
                  )}
                  {activeTournament.status === 'in_progress' && (
                    <button
                      onClick={() => handleToggleStatus('registration_open')}
                      disabled={processing}
                      className="flex items-center gap-2 px-4 py-2.5 bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-zinc-300 text-xs font-bold rounded-xl transition-all"
                    >
                      <span>فتح التسجيل مجدداً 🔓</span>
                    </button>
                  )}
                  <button
                    onClick={handleSaveDraft}'''

if old_controls in text:
    text = text.replace(old_controls, new_controls)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)

print('Successfully added status toggle to League1v1Page.jsx!')

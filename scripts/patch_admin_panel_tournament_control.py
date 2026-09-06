import os

admin_service_path = '../vsp_admin_panel/src/services/adminService.js'
tournament_page_path = '../vsp_admin_panel/src/pages/TournamentControlPage.jsx'

# 1. Update adminService.js
with open(admin_service_path, 'r', encoding='utf-8') as f:
    service_content = f.read()

new_service_method = """  async markChampionshipPrizeDelivered(championshipId, notes = '') {
    try {
      const { data, error } = await this.client.rpc('mark_championship_prize_delivered_atomic', {
        p_championship_id: championshipId,
        p_notes: notes,
      });
      if (error) throw error;
      return { success: true, data };
    } catch (e) {
      console.error('Error in markChampionshipPrizeDelivered:', e);
      const err = classifyError(e);
      return { success: false, error: err.message, errorType: err.type };
    }
  }

"""

if 'markChampionshipPrizeDelivered' not in service_content:
    target = '  // =========================================================================\n  // MODULE E: DISPUTES RESOLUTION & REPORTS'
    service_content = service_content.replace(target, new_service_method + target)
    with open(admin_service_path, 'w', encoding='utf-8') as f:
        f.write(service_content)
    print("Updated adminService.js with markChampionshipPrizeDelivered.")
else:
    print("markChampionshipPrizeDelivered already in adminService.js.")

# 2. Update TournamentControlPage.jsx
with open(tournament_page_path, 'r', encoding='utf-8') as f:
    page_content = f.read()

# Add state variables
old_state = "  const [confirmingBracket, setConfirmingBracket] = useState(false);\n\n  const [toast, setToast] = useState(null);"
new_state = """  const [confirmingBracket, setConfirmingBracket] = useState(false);
  const [selectedForPrizeDelivery, setSelectedForPrizeDelivery] = useState(null);
  const [deliveryNotes, setDeliveryNotes] = useState('');
  const [confirmDeliveryCheck, setConfirmDeliveryCheck] = useState(false);
  const [deliveringPrize, setDeliveringPrize] = useState(false);

  const [toast, setToast] = useState(null);"""

if 'selectedForPrizeDelivery' not in page_content:
    page_content = page_content.replace(old_state, new_state)

# Add executeMarkPrizeDelivered handler
handler_target = "  const executeGenerateBracket = async (id) => {"
new_handler = """  const executeMarkPrizeDelivered = async () => {
    if (!selectedForPrizeDelivery) return;
    setDeliveringPrize(true);
    try {
      const res = await adminService.markChampionshipPrizeDelivered(
        selectedForPrizeDelivery.id,
        deliveryNotes
      );
      if (res && res.success !== false) {
        showToast('تم توثيق تسليم الجائزة وإدراجها في السجل المالي بنجاح');
        setSelectedForPrizeDelivery(null);
        setDeliveryNotes('');
        setConfirmDeliveryCheck(false);
        fetchTournaments();
      } else {
        showToast(res?.error || 'فشل في توثيق تسليم الجائزة', 'error');
      }
    } catch (e) {
      showToast(e.message || 'حدث خطأ أثناء توثيق التسليم', 'error');
    } finally {
      setDeliveringPrize(false);
    }
  };

"""
if 'executeMarkPrizeDelivered' not in page_content:
    page_content = page_content.replace(handler_target, new_handler + handler_target)

# Add Modal before Header
modal_target = "      {/* Header */}"
new_modal = """      {/* Prize Delivery Handover Modal */}
      {selectedForPrizeDelivery && (
        <Modal
          isOpen={true}
          onClose={() => {
            if (!deliveringPrize) {
              setSelectedForPrizeDelivery(null);
              setDeliveryNotes('');
              setConfirmDeliveryCheck(false);
            }
          }}
          title="توثيق تسليم الجائزة المالية للبطولة"
          maxWidth="max-w-md"
        >
          <div className="space-y-4">
            <div className="p-3 bg-vsp-surfaceAlt rounded-xl border border-vsp-border space-y-2">
              <div className="flex items-center justify-between text-xs">
                <span className="text-vsp-textSecondary">البطولة:</span>
                <span className="font-bold text-white">{selectedForPrizeDelivery.name}</span>
              </div>
              <div className="flex items-center justify-between text-xs">
                <span className="text-vsp-textSecondary">الفريق البطل:</span>
                <span className="font-bold text-vsp-accent">
                  {selectedForPrizeDelivery.champion_team_name || selectedForPrizeDelivery.winner_team_name || 'الفريق الفائز'}
                </span>
              </div>
              <div className="flex items-center justify-between text-xs">
                <span className="text-vsp-textSecondary">قيمة الجائزة المسلمة (الوعاء الفعلي):</span>
                <span className="font-bold text-emerald-400 text-sm">
                  {Number(selectedForPrizeDelivery.prize_pool || selectedForPrizeDelivery.grand_prize || 0).toLocaleString()} {t('currency')}
                </span>
              </div>
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-bold text-zinc-300">
                ملاحظات التسليم وطريقة التحويل
              </label>
              <textarea
                value={deliveryNotes}
                onChange={(e) => setDeliveryNotes(e.target.value)}
                placeholder="مثال: تم التحويل بنكياً على محفظة كابتن الفريق / تسليم نقدي في الملعب بحضور الإدارة..."
                className="w-full h-20 p-2.5 bg-vsp-surfaceAlt border border-vsp-border rounded-xl text-xs text-white placeholder-zinc-500 focus:border-vsp-accent outline-none resize-none"
              />
            </div>

            <label className="flex items-center gap-2 cursor-pointer pt-1">
              <input
                type="checkbox"
                checked={confirmDeliveryCheck}
                onChange={(e) => setConfirmDeliveryCheck(e.target.checked)}
                className="rounded border-zinc-700 text-vsp-accent focus:ring-0 w-4 h-4 bg-zinc-900"
              />
              <span className="text-xs text-zinc-300 select-none">
                أقر بتسليم كامل مبلغ الجائزة وتوثيق الحركة في سجل المعاملات المالية
              </span>
            </label>

            <div className="flex items-center gap-3 pt-2">
              <button
                type="button"
                disabled={deliveringPrize}
                onClick={() => {
                  setSelectedForPrizeDelivery(null);
                  setDeliveryNotes('');
                  setConfirmDeliveryCheck(false);
                }}
                className="flex-1 py-2.5 bg-vsp-surfaceAlt hover:bg-vsp-card text-vsp-textSecondary hover:text-white rounded-xl text-xs font-bold transition-all border border-vsp-border"
              >
                إلغاء
              </button>
              <button
                type="button"
                disabled={deliveringPrize || !confirmDeliveryCheck}
                onClick={executeMarkPrizeDelivered}
                className={`flex-1 py-2.5 rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition-all shadow-lg ${
                  !confirmDeliveryCheck || deliveringPrize
                    ? 'bg-zinc-800 text-zinc-500 cursor-not-allowed'
                    : 'bg-emerald-500 hover:bg-emerald-400 text-black shadow-emerald-500/20'
                }`}
              >
                {deliveringPrize ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <Award className="w-4 h-4" />
                )}
                <span>تأكيد التسليم وتوثيق السجل</span>
              </button>
            </div>
          </div>
        </Modal>
      )}

"""
if 'Prize Delivery Handover Modal' not in page_content:
    page_content = page_content.replace(modal_target, new_modal + modal_target)

# Update prize display in card
old_prize_block = """                    <div className="flex items-center gap-1.5 text-vsp-textSecondary">
                      <Award className="w-3.5 h-3.5 text-zinc-400" />
                      <span>{champ.grand_prize && Number(champ.grand_prize) > 0 ? `${Number(champ.grand_prize).toLocaleString()} ${t('currency')}` : (champ.trophy_medals ? 'كأس وميداليات' : 'بطولة شرفية')}</span>
                    </div>"""

new_prize_block = """                    <div className="flex items-center gap-1.5 text-vsp-textSecondary">
                      <Award className="w-3.5 h-3.5 text-vsp-accent" />
                      <span>
                        {champ.prize_pool && Number(champ.prize_pool) > 0
                          ? `${Number(champ.prize_pool).toLocaleString()} ${t('currency')} (وعاء فعلي)`
                          : champ.grand_prize && Number(champ.grand_prize) > 0
                          ? `${Number(champ.grand_prize).toLocaleString()} ${t('currency')}`
                          : (champ.trophy_medals ? 'كأس وميداليات' : 'بطولة شرفية')}
                      </span>
                    </div>"""

if old_prize_block in page_content:
    page_content = page_content.replace(old_prize_block, new_prize_block)

# Add Delivery Status card for completed championships
old_actions_start = """                {/* Actions */}
                <div className="space-y-2 pt-3 border-t border-vsp-border">"""

new_actions_start = """                {/* Completed Delivery Ledger Status */}
                {isCompleted && (
                  <div className="p-2.5 rounded-xl bg-zinc-900/60 border border-zinc-800 space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-[11px] text-zinc-400 font-medium">حالة الجائزة:</span>
                      {champ.prize_delivered ? (
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                          تم التسليم
                        </span>
                      ) : (
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-500/10 text-amber-400 border border-amber-500/20">
                          بانتظار التسليم
                        </span>
                      )}
                    </div>
                    {champ.prize_delivered ? (
                      <div className="text-[10px] text-zinc-500 line-clamp-1">
                        {champ.prize_delivery_notes ? `ملاحظات: ${champ.prize_delivery_notes}` : 'تم التوثيق في السجل المالي'}
                      </div>
                    ) : (
                      <button
                        type="button"
                        onClick={() => setSelectedForPrizeDelivery(champ)}
                        className="w-full py-1.5 bg-emerald-500/10 hover:bg-emerald-500/20 border border-emerald-500/30 text-emerald-400 rounded-lg text-xs font-bold transition-all flex items-center justify-center gap-1.5"
                      >
                        <Award className="w-3.5 h-3.5" />
                        <span>توثيق تسليم الجائزة للبطل</span>
                      </button>
                    )}
                  </div>
                )}

                {/* Actions */}
                <div className="space-y-2 pt-3 border-t border-vsp-border">"""

if old_actions_start in page_content and 'Completed Delivery Ledger Status' not in page_content:
    page_content = page_content.replace(old_actions_start, new_actions_start)

with open(tournament_page_path, 'w', encoding='utf-8') as f:
    f.write(page_content)
print("Updated TournamentControlPage.jsx successfully.")

import os
import sys

# 1. Update adminService.js
admin_service_path = r'k:\.gemini\antigravity\scratch\vsp_admin_panel\src\services\adminService.js'
with open(admin_service_path, 'r', encoding='utf-8') as f:
    as_content = f.read()

target_rpc_call = """  async prepareTournamentBracket(championshipId) {
    try {
      const { data, error } = await this.client.rpc('prepare_tournament_bracket_atomic', {
        p_championship_id: championshipId,
      });
      if (error) throw error;
      return { success: true, data };
    } catch (e) {
      console.error('Error in prepareTournamentBracket:', e);
      const err = classifyError(e);
      return { success: false, error: err.message, errorType: err.type };
    }
  }"""

replacement_rpc_call = """  async prepareTournamentBracket(championshipId) {
    try {
      // First try the new centralized atomic bracket generator
      const { data, error } = await this.client.rpc('generate_tournament_bracket_atomic', {
        p_championship_id: championshipId,
      });
      if (error) {
        // Fallback to prepare_tournament_bracket_atomic
        const fallback = await this.client.rpc('prepare_tournament_bracket_atomic', {
          p_championship_id: championshipId,
        });
        if (fallback.error) throw fallback.error;
        return { success: true, data: fallback.data };
      }
      return { success: true, data };
    } catch (e) {
      console.error('Error in prepareTournamentBracket:', e);
      const err = classifyError(e);
      return { success: false, error: err.message, errorType: err.type };
    }
  }"""

if target_rpc_call in as_content:
    as_content = as_content.replace(target_rpc_call, replacement_rpc_call)
    with open(admin_service_path, 'w', encoding='utf-8') as f:
        f.write(as_content)
    print("✅ adminService.js prepareTournamentBracket patched successfully!")
else:
    print("ℹ️ prepareTournamentBracket already updated or target block not found verbatim.")


# 2. Update TournamentControlPage.jsx
tcp_path = r'k:\.gemini\antigravity\scratch\vsp_admin_panel\src\pages\TournamentControlPage.jsx'

new_tcp_content = '''import React, { useState, useEffect } from 'react';
import { adminService } from '../services/adminService';
import { useLanguage } from '../context/LanguageContext';
import { Toast } from '../components/ui/Toast';
import { Badge } from '../components/ui/Badge';
import { Modal } from '../components/ui/Modal';
import { EmptyState } from '../components/ui/EmptyState';
import {
  Trophy,
  RefreshCw,
  CheckCircle,
  Clock,
  Play,
  Loader2,
  Calendar,
  Users,
  Building2,
  GitBranch,
  Flame,
  Award,
  AlertTriangle,
} from 'lucide-react';

export const TournamentControlPage = () => {
  const { t } = useLanguage();
  const [loading, setLoading] = useState(true);
  const [championships, setChampionships] = useState([]);
  const [updatingId, setUpdatingId] = useState(null);
  const [selectedForBracket, setSelectedForBracket] = useState(null);
  const [confirmingBracket, setConfirmingBracket] = useState(false);

  const [toast, setToast] = useState(null);

  const showToast = (message, type = 'success') => {
    setToast({ message, type });
  };

  const fetchTournaments = async () => {
    setLoading(true);
    try {
      const data = await adminService.fetchChampionships();
      setChampionships(data || []);
    } catch (e) {
      showToast(t('error_loading'), 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchTournaments();
  }, []);

  const updateStatus = async (id, nextStatus) => {
    setUpdatingId(id);
    try {
      const res = await adminService.updateChampionshipStatus(id, nextStatus);
      if (res.success) {
        showToast(t('toast_status_updated'));
        fetchTournaments();
      } else {
        showToast(res.error || t('toast_fail_generic'), 'error');
      }
    } catch (e) {
      showToast(e.message, 'error');
    } finally {
      setUpdatingId(null);
    }
  };

  const executeGenerateBracket = async (id) => {
    setConfirmingBracket(true);
    setUpdatingId(id);
    try {
      const res = await adminService.prepareTournamentBracket(id);
      if (res.success) {
        showToast(t('toast_bracket_generated') || 'تم إطلاق القرعة وتوليد شجرة المباريات بنجاح.');
        setSelectedForBracket(null);
        fetchTournaments();
      } else {
        showToast(res.error || t('toast_fail_generic'), 'error');
      }
    } catch (e) {
      showToast(e.message, 'error');
    } finally {
      setConfirmingBracket(false);
      setUpdatingId(null);
    }
  };

  return (
    <div className="p-6 space-y-6">
      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}

      {/* Confirmation Modal for Bracket Generation */}
      {selectedForBracket && (
        <Modal
          isOpen={!!selectedForBracket}
          onClose={() => !confirmingBracket && setSelectedForBracket(null)}
          title="تأكيد إطلاق القرعة وتوليد شجرة المباريات"
        >
          <div className="space-y-4">
            <div className="p-3 bg-amber-500/10 border border-amber-500/20 rounded-xl flex items-start gap-3">
              <AlertTriangle className="w-5 h-5 text-amber-400 shrink-0 mt-0.5" />
              <div className="text-xs text-amber-200/90 leading-relaxed">
                <p className="font-bold text-amber-300 mb-1">
                  تنبيه أمني وتنظيمي:
                </p>
                سيتم سحب الفرق عشوائياً وتوليد شجرة الأدوار والإقصائيات فوراً.
                تأكد من استيفاء شروط السداد لكافة الفرق قبل إطلاق القرعة، حيث لن يسمح بمسح أو تعديل الفرق بعد انطلاق المباريات.
              </div>
            </div>

            <div className="bg-vsp-surfaceAlt p-4 rounded-xl space-y-2.5 text-xs border border-vsp-border">
              <div className="flex justify-between text-vsp-textSecondary">
                <span>اسم البطولة:</span>
                <span className="font-bold text-white">{selectedForBracket.name}</span>
              </div>
              <div className="flex justify-between text-vsp-textSecondary">
                <span>الفرق المسددة / المؤهلة:</span>
                <span className="font-bold text-vsp-accent">
                  {(selectedForBracket.paid_teams?.length || selectedForBracket.joined_teams?.length || 0)} من أصل {selectedForBracket.max_teams || 16}
                </span>
              </div>
              <div className="flex justify-between text-vsp-textSecondary">
                <span>رسوم الاشتراك:</span>
                <span className="font-bold text-white">
                  {selectedForBracket.entry_fee ? `${Number(selectedForBracket.entry_fee).toLocaleString()} ج.م` : 'مجانية'}
                </span>
              </div>
            </div>

            <div className="flex items-center gap-3 pt-2">
              <button
                type="button"
                disabled={confirmingBracket}
                onClick={() => setSelectedForBracket(null)}
                className="flex-1 py-2.5 bg-vsp-surfaceAlt hover:bg-vsp-card text-vsp-textSecondary hover:text-white rounded-xl text-xs font-bold transition-all border border-vsp-border"
              >
                إلغاء
              </button>
              <button
                type="button"
                disabled={confirmingBracket}
                onClick={() => executeGenerateBracket(selectedForBracket.id)}
                className="flex-1 py-2.5 bg-vsp-accent hover:bg-vsp-accent/90 text-black rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition-all shadow-lg shadow-vsp-accent/20"
              >
                {confirmingBracket ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <GitBranch className="w-4 h-4" />
                )}
                <span>تأكيد وإطلاق القرعة</span>
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-black text-white flex items-center gap-2">
            <Trophy className="w-6 h-6 text-vsp-accent" />
            <span>{t('tournaments_title')}</span>
          </h1>
          <p className="text-xs text-vsp-textSecondary mt-0.5">
            {t('tournaments_subtitle')}
          </p>
        </div>

        <button
          onClick={fetchTournaments}
          className="p-2.5 bg-vsp-surface hover:bg-vsp-card border border-vsp-border text-vsp-textSecondary hover:text-white rounded-xl transition-all self-end sm:self-auto"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
        </button>
      </div>

      {/* Content */}
      {loading ? (
        <div className="h-64 flex items-center justify-center">
          <Loader2 className="w-8 h-8 text-vsp-accent animate-spin" />
        </div>
      ) : championships.length === 0 ? (
        <EmptyState
          icon={Trophy}
          title={t('no_tournaments_title')}
          subtitle=""
        />
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {championships.map((champ) => {
            const isProcessing = updatingId === champ.id;
            const status = champ.status || 'draft';
            const isOngoing = status === 'ongoing' || status === 'in_progress' || status === 'active';
            const isCompleted = status === 'completed';

            return (
              <div
                key={champ.id}
                className="bg-vsp-surface border border-vsp-border hover:border-zinc-700 rounded-2xl p-5 space-y-4 transition-all flex flex-col justify-between"
              >
                <div className="space-y-3">
                  <div className="flex items-start justify-between gap-2">
                    <h3 className="font-bold text-white text-sm line-clamp-1">{champ.name}</h3>
                    <Badge
                      variant={
                        isOngoing
                          ? 'accent'
                          : isCompleted
                          ? 'success'
                          : status === 'open' || status === 'registration_open'
                          ? 'blue'
                          : 'default'
                      }
                      size="xs"
                    >
                      {status === 'open' ? 'تسجيل مفتوح' : status === 'ongoing' ? 'جارية' : status === 'completed' ? 'مكتملة' : status}
                    </Badge>
                  </div>

                  <p className="text-[11px] text-vsp-textSecondary line-clamp-2 leading-relaxed">
                    {champ.rules || `${champ.sport_type || 'Football'}`}
                  </p>

                  <div className="grid grid-cols-2 gap-2 pt-2 border-t border-vsp-border/50 text-xs">
                    <div className="flex items-center gap-1.5 text-vsp-textSecondary">
                      <Users className="w-3.5 h-3.5 text-vsp-accent" />
                      <span>{champ.max_teams || 16} {t('teams_count_col')}</span>
                    </div>

                    <div className="flex items-center gap-1.5 text-vsp-textSecondary">
                      <Award className="w-3.5 h-3.5 text-zinc-400" />
                      <span>{champ.grand_prize && Number(champ.grand_prize) > 0 ? `${Number(champ.grand_prize).toLocaleString()} ${t('currency')}` : (champ.trophy_medals ? 'كأس وميداليات' : 'بطولة شرفية')}</span>
                    </div>
                  </div>
                </div>

                {/* Actions */}
                <div className="space-y-2 pt-3 border-t border-vsp-border">
                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => setSelectedForBracket(champ)}
                      disabled={isProcessing || isOngoing || isCompleted}
                      title={isOngoing ? 'القرعة جارية بالفعل' : isCompleted ? 'البطولة منتهية' : 'إطلاق القرعة وتوليد شجرة المباريات'}
                      className={`flex-1 py-2 font-bold text-[11px] rounded-xl flex items-center justify-center gap-1.5 transition-all border ${
                        isOngoing || isCompleted
                          ? 'bg-zinc-900/40 text-zinc-500 border-zinc-800 cursor-not-allowed'
                          : 'bg-vsp-card hover:bg-vsp-border border-vsp-border text-white hover:border-vsp-accent/40'
                      }`}
                    >
                      <GitBranch className={`w-3.5 h-3.5 ${isOngoing || isCompleted ? 'text-zinc-600' : 'text-vsp-accent'}`} />
                      <span>{isOngoing ? 'القرعة جارية' : isCompleted ? 'مكتملة' : (t('generate_bracket_btn') || 'توليد القرعة')}</span>
                    </button>

                    <button
                      onClick={() =>
                        updateStatus(champ.id, isOngoing ? 'completed' : 'ongoing')
                      }
                      disabled={isProcessing}
                      className="flex-1 py-2 bg-zinc-800 hover:bg-zinc-700 text-white border border-zinc-700 hover:border-zinc-500 font-bold text-[11px] rounded-xl flex items-center justify-center gap-1.5 transition-all"
                    >
                      {isOngoing ? <CheckCircle className="w-3.5 h-3.5 text-vsp-accent" /> : <Play className="w-3.5 h-3.5 text-zinc-400" />}
                      <span>{isOngoing ? t('completed') : 'بدء البطولة'}</span>
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
'''

with open(tcp_path, 'w', encoding='utf-8') as f:
    f.write(new_tcp_content)

print("✅ TournamentControlPage.jsx updated with safety modal, status locks, and atomic bracket execution!")

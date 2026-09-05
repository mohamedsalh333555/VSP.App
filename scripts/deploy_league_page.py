import os

code = """import React, { useState, useEffect } from 'react';
import { adminService } from '../services/adminService';
import { useLanguage } from '../context/LanguageContext';
import { Toast } from '../components/ui/Toast';
import { Modal } from '../components/ui/Modal';
import { Badge } from '../components/ui/Badge';
import { EmptyState } from '../components/ui/EmptyState';
import {
  Flame,
  Trophy,
  UserPlus,
  CheckCircle2,
  XCircle,
  RotateCcw,
  Trash2,
  TrendingUp,
  TrendingDown,
  Minus,
  Loader2,
  Lock,
  Unlock,
  Edit2,
  Plus,
  RefreshCw,
  Send,
  FileSpreadsheet,
  Shield,
  Target,
  Zap,
  ArrowRight,
} from 'lucide-react';

export const League1v1Page = () => {
  const { t } = useLanguage();
  const [activeTab, setActiveTab] = useState('standings'); // 'standings' | 'registrations'
  const [loading, setLoading] = useState(true);
  const [players, setPlayers] = useState([]);
  const [registrations, setRegistrations] = useState([]);
  const [isOpen, setIsOpen] = useState(true);
  const [approvedCount, setApprovedCount] = useState(0);
  const [processing, setProcessing] = useState(false);
  const [toast, setToast] = useState(null);

  // New Tournament Modal State (Manual count input)
  const [showNewTournamentModal, setShowNewTournamentModal] = useState(false);
  const [tournamentName, setTournamentName] = useState('بطولة 1vs1 الرسمية');
  const [playerCountInput, setPlayerCountInput] = useState(16);

  // Bulk Scoresheet Mode State
  const [isScoresheetMode, setIsScoresheetMode] = useState(false);
  const [sheetPlayers, setSheetPlayers] = useState([]);

  const showToast = (message, type = 'success') => {
    setToast({ message, type });
  };

  const fetch1v1Data = async () => {
    setLoading(true);
    try {
      const [playersData, regData, gateStatus, approvedTotal] = await Promise.all([
        adminService.fetch1v1LeaguePlayers(),
        adminService.fetch1v1PendingRegistrations(),
        adminService.fetch1v1RegistrationOpenStatus(),
        adminService.fetch1v1ApprovedCount(),
      ]);

      setPlayers(playersData || []);
      setRegistrations(regData || []);
      setIsOpen(gateStatus);
      setApprovedCount(approvedTotal);
    } catch (e) {
      showToast(t('error_loading') || 'حدث خطأ في جلب البيانات', 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetch1v1Data();
  }, []);

  // Toggle Gate
  const toggleGate = async () => {
    setProcessing(true);
    try {
      const nextState = !isOpen;
      const res = await adminService.set1v1RegistrationOpenStatus(nextState);
      if (res.success) {
        setIsOpen(nextState);
        showToast(nextState ? 'تم فتح بوابة التسجيل للاعبين' : 'تم إغلاق بوابة التسجيل');
      } else {
        showToast(t('toast_fail_generic') || 'فشلت العملية', 'error');
      }
    } catch (e) {
      showToast(e.message, 'error');
    } finally {
      setProcessing(false);
    }
  };

  // Start New Tournament: wipe previous and create N empty rows
  const handleConfirmStartTournament = async (e) => {
    e.preventDefault();
    const count = parseInt(playerCountInput) || 8;
    if (count <= 0) {
      showToast('يرجى إدخال عدد لاعبين صحيح', 'error');
      return;
    }

    setProcessing(true);
    try {
      // 1. Wipe previous records in database
      const res = await adminService.wipe1v1TournamentData();
      if (!res.success) throw new Error(res.error || 'Failed to wipe');

      // 2. Generate N empty rows ready for scoring
      const initialRows = Array.from({ length: count }, (_, i) => ({
        id: `temp_${Date.now()}_${i}`,
        name: '',
        tackles: 0,
        goals: 0,
        skill_points: 0,
        total_points: 0,
      }));

      setSheetPlayers(initialRows);
      setIsScoresheetMode(true);
      setShowNewTournamentModal(false);
      showToast(`تم بدء بطولة جديدة وتجهيز شيت رصد لـ ${count} لاعباً! 🏆`);
      fetch1v1Data();
    } catch (e) {
      showToast(e.message || 'حدث خطأ أثناء بدء البطولة', 'error');
    } finally {
      setProcessing(false);
    }
  };

  // Open scoresheet with current players for editing
  const handleOpenEditScoresheet = () => {
    if (players.length === 0) {
      const initialRows = Array.from({ length: 16 }, (_, i) => ({
        id: `temp_${Date.now()}_${i}`,
        name: '',
        tackles: 0,
        goals: 0,
        skill_points: 0,
        total_points: 0,
      }));
      setSheetPlayers(initialRows);
    } else {
      setSheetPlayers(
        players.map((p) => ({
          id: p.id,
          name: p.name || '',
          tackles: p.tackles || 0,
          goals: p.goals || 0,
          skill_points: p.skill_points || 0,
          total_points: (p.tackles || 0) + (p.goals || 0) + (p.skill_points || 0),
        }))
      );
    }
    setIsScoresheetMode(true);
  };

  // Update cell in bulk sheet
  const handleUpdateSheetRow = (id, field, val) => {
    setSheetPlayers((prev) =>
      prev.map((row) => {
        if (row.id !== id) return row;
        const updated = { ...row, [field]: val };
        if (field === 'tackles' || field === 'goals' || field === 'skill_points') {
          const t = Math.max(0, parseInt(field === 'tackles' ? val : row.tackles) || 0);
          const g = Math.max(0, parseInt(field === 'goals' ? val : row.goals) || 0);
          const s = Math.max(0, parseInt(field === 'skill_points' ? val : row.skill_points) || 0);
          updated.total_points = t + g + s; // 1 point each
        }
        return updated;
      })
    );
  };

  // Add extra row to sheet
  const handleAddSheetRow = () => {
    setSheetPlayers((prev) => [
      ...prev,
      {
        id: `temp_${Date.now()}_${prev.length}`,
        name: '',
        tackles: 0,
        goals: 0,
        skill_points: 0,
        total_points: 0,
      },
    ]);
  };

  // Remove row from sheet
  const handleRemoveSheetRow = (id) => {
    setSheetPlayers((prev) => prev.filter((r) => r.id !== id));
  };

  // Publish Standings to Supabase
  const handlePublishStandings = async () => {
    const validRows = sheetPlayers.filter((p) => p.name.trim().length > 0);
    if (validRows.length === 0) {
      showToast('يرجى كتابة اسم لاعب واحد على الأقل قبل النشر', 'error');
      return;
    }

    setProcessing(true);
    try {
      const res = await adminService.publish1v1Standings(validRows);
      if (res.success) {
        showToast('تم نشر ترتيب البطولة وتحديث تطبيق الموبايل لحظياً! 🚀', 'success');
        setIsScoresheetMode(false);
        fetch1v1Data();
      } else {
        showToast(res.error || 'فشل في نشر الترتيب', 'error');
      }
    } catch (e) {
      showToast(e.message, 'error');
    } finally {
      setProcessing(false);
    }
  };

  // Approve registration
  const approveReg = async (reg) => {
    setProcessing(true);
    try {
      const res = await adminService.approve1v1Registration({
        registrationId: reg.id,
        userId: reg.user_id,
        name: reg.player_name || reg.name || reg.users?.name,
        avatarUrl: reg.avatar_url || reg.users?.profile_image_url,
      });

      if (res.success) {
        showToast('تم قبول اللاعب وإضافته لقائمة البطولة');
        fetch1v1Data();
      } else {
        showToast(res.error || t('toast_fail_generic'), 'error');
      }
    } catch (e) {
      showToast(e.message, 'error');
    } finally {
      setProcessing(false);
    }
  };

  // Reject registration
  const rejectReg = async (regId) => {
    setProcessing(true);
    try {
      const res = await adminService.reject1v1Registration(regId);
      if (res.success) {
        showToast('تم رفض الطلب');
        fetch1v1Data();
      } else {
        showToast(res.error || t('toast_fail_generic'), 'error');
      }
    } catch (e) {
      showToast(e.message, 'error');
    } finally {
      setProcessing(false);
    }
  };

  return (
    <div className="p-6 space-y-6 text-right" dir="rtl">
      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={() => setToast(null)}
        />
      )}

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-white flex items-center gap-2.5">
            <Flame className="w-7 h-7 text-amber-500" />
            <span>دوري المواجهات الفردية (1vs1)</span>
          </h1>
          <p className="text-xs text-vsp-textSecondary mt-1">
            إدارة بطولات اليوم الواحد (ساعتين)، رصد النقاط دفعة واحدة من الورق، والنشر الفوري للموبايل.
          </p>
        </div>

        <div className="flex items-center gap-2.5 flex-wrap">
          <button
            onClick={fetch1v1Data}
            className="p-2.5 bg-vsp-surface hover:bg-vsp-card border border-vsp-border text-vsp-textSecondary hover:text-white rounded-xl transition-all"
            title="تحديث"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          </button>

          {/* Toggle Registration Gate */}
          <button
            onClick={toggleGate}
            disabled={processing}
            className={`flex items-center gap-2 px-4 py-2.5 rounded-xl text-xs font-bold border transition-all ${
              isOpen
                ? 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30 hover:bg-emerald-500/25'
                : 'bg-red-500/15 text-red-400 border-red-500/30 hover:bg-red-500/25'
            }`}
          >
            {isOpen ? <Unlock className="w-4 h-4" /> : <Lock className="w-4 h-4" />}
            <span>{isOpen ? 'بوابة التسجيل: مفتوحة' : 'بوابة التسجيل: مغلقة'}</span>
          </button>

          {/* Start New Tournament with manual player count */}
          <button
            onClick={() => setShowNewTournamentModal(true)}
            className="flex items-center gap-2 px-4 py-2.5 bg-amber-500/15 hover:bg-amber-500/25 border border-amber-500/40 text-amber-400 text-xs font-bold rounded-xl transition-all shadow-sm"
          >
            <RotateCcw className="w-4 h-4" />
            <span>بدء بطولة جديدة 🏆</span>
          </button>

          {/* Open Scoresheet Sheet Button */}
          {!isScoresheetMode ? (
            <button
              onClick={handleOpenEditScoresheet}
              className="flex items-center gap-2 px-5 py-2.5 bg-vsp-accent text-black font-black text-xs rounded-xl transition-all shadow-lg hover:brightness-110"
            >
              <FileSpreadsheet className="w-4 h-4" />
              <span>شيت رصد الدرجات 📝</span>
            </button>
          ) : (
            <button
              onClick={() => setIsScoresheetMode(false)}
              className="flex items-center gap-1.5 px-4 py-2.5 bg-vsp-surface border border-vsp-border text-white text-xs font-bold rounded-xl"
            >
              <ArrowRight className="w-4 h-4" />
              <span>العودة لعرض الترتيب</span>
            </button>
          )}
        </div>
      </div>

      {/* ==================================================================== */}
      {/* MODE 1: BULK SCORESHEET ENTRY (رصد النقاط دفعة واحدة من الورق) */}
      {/* ==================================================================== */}
      {isScoresheetMode ? (
        <div className="bg-vsp-surface border border-vsp-accent/30 rounded-2xl p-6 space-y-5 shadow-2xl">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-vsp-border pb-4">
            <div>
              <div className="flex items-center gap-2">
                <Badge variant="accent" size="sm">
                  شيت الرصد المباشر
                </Badge>
                <h3 className="text-base font-black text-white">
                  رصد درجات بطولة 1vs1 (المعادلة: تاكلينج + أهداف + مهارة = 1 نقطة لكل حركة)
                </h3>
              </div>
              <p className="text-xs text-zinc-400 mt-1">
                اكتب أسماء اللاعبين وأرقامهم من واقع ورقة التحكيم. يتم جمع النقاط تلقائياً وترتيبهم بالمركز.
              </p>
            </div>

            <div className="flex items-center gap-3">
              <button
                onClick={handleAddSheetRow}
                className="flex items-center gap-1.5 px-3.5 py-2 bg-vsp-card hover:bg-vsp-surface border border-vsp-border text-white text-xs font-bold rounded-xl transition-all"
              >
                <Plus className="w-4 h-4 text-vsp-accent" />
                <span>+ إضافة لاعب إضافي</span>
              </button>

              <button
                onClick={handlePublishStandings}
                disabled={processing}
                className="flex items-center gap-2 px-6 py-2.5 bg-vsp-accent text-black font-black text-xs rounded-xl shadow-lg hover:brightness-110 transition-all disabled:opacity-50"
              >
                {processing ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
                <span>نشر الترتيب للموبايل لحظياً 🚀</span>
              </button>
            </div>
          </div>

          {/* Scoresheet Table */}
          <div className="overflow-x-auto">
            <table className="w-full text-right text-xs">
              <thead className="bg-vsp-card text-vsp-textSecondary border-b border-vsp-border">
                <tr>
                  <th className="px-4 py-3 font-bold text-center w-12">#</th>
                  <th className="px-4 py-3 font-bold w-64">اسم اللاعب</th>
                  <th className="px-4 py-3 font-bold text-center">
                    <div className="flex items-center justify-center gap-1">
                      <Shield className="w-3.5 h-3.5 text-blue-400" />
                      <span>تدخل صحيح (تاكلينج)</span>
                    </div>
                  </th>
                  <th className="px-4 py-3 font-bold text-center">
                    <div className="flex items-center justify-center gap-1">
                      <Target className="w-3.5 h-3.5 text-emerald-400" />
                      <span>أهداف (1 pt)</span>
                    </div>
                  </th>
                  <th className="px-4 py-3 font-bold text-center">
                    <div className="flex items-center justify-center gap-1">
                      <Zap className="w-3.5 h-3.5 text-amber-400" />
                      <span>مهارة (1 pt)</span>
                    </div>
                  </th>
                  <th className="px-4 py-3 font-bold text-center w-32 bg-vsp-accent/10 text-vsp-accent">
                    <span>المجموع الكلي (PTS)</span>
                  </th>
                  <th className="px-4 py-3 font-bold text-center w-16">حذف</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-vsp-border/40">
                {sheetPlayers.map((player, idx) => {
                  return (
                    <tr key={player.id} className="hover:bg-vsp-card/30 transition-colors">
                      <td className="px-4 py-2.5 text-center font-black text-zinc-500 text-sm">
                        {idx + 1}
                      </td>

                      {/* Name input */}
                      <td className="px-4 py-2.5">
                        <input
                          type="text"
                          value={player.name}
                          onChange={(e) => handleUpdateSheetRow(player.id, 'name', e.target.value)}
                          placeholder={`اسم اللاعب #${idx + 1}`}
                          className="w-full bg-vsp-card border border-vsp-border rounded-lg px-3 py-1.5 text-white font-bold text-xs focus:border-vsp-accent focus:outline-none"
                        />
                      </td>

                      {/* Tackles */}
                      <td className="px-4 py-2.5 text-center">
                        <input
                          type="number"
                          min="0"
                          value={player.tackles}
                          onChange={(e) => handleUpdateSheetRow(player.id, 'tackles', e.target.value)}
                          className="w-20 mx-auto text-center bg-vsp-card border border-vsp-border rounded-lg px-2 py-1.5 text-white font-bold text-xs focus:border-blue-400 focus:outline-none"
                        />
                      </td>

                      {/* Goals */}
                      <td className="px-4 py-2.5 text-center">
                        <input
                          type="number"
                          min="0"
                          value={player.goals}
                          onChange={(e) => handleUpdateSheetRow(player.id, 'goals', e.target.value)}
                          className="w-20 mx-auto text-center bg-vsp-card border border-vsp-border rounded-lg px-2 py-1.5 text-white font-bold text-xs focus:border-emerald-400 focus:outline-none"
                        />
                      </td>

                      {/* Skills */}
                      <td className="px-4 py-2.5 text-center">
                        <input
                          type="number"
                          min="0"
                          value={player.skill_points}
                          onChange={(e) => handleUpdateSheetRow(player.id, 'skill_points', e.target.value)}
                          className="w-20 mx-auto text-center bg-vsp-card border border-vsp-border rounded-lg px-2 py-1.5 text-white font-bold text-xs focus:border-amber-400 focus:outline-none"
                        />
                      </td>

                      {/* Total Points (Auto-calculated) */}
                      <td className="px-4 py-2.5 text-center bg-vsp-accent/5">
                        <span className="text-sm font-black text-vsp-accent">
                          {player.total_points || 0} pts
                        </span>
                      </td>

                      {/* Delete row */}
                      <td className="px-4 py-2.5 text-center">
                        <button
                          type="button"
                          onClick={() => handleRemoveSheetRow(player.id)}
                          className="p-1.5 text-zinc-500 hover:text-red-400 hover:bg-red-500/10 rounded-lg transition-colors"
                          title="حذف الصف"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          <div className="flex items-center justify-between pt-2">
            <span className="text-xs text-zinc-400 font-bold">
              إجمالي اللاعبين في الشيت: {sheetPlayers.length}
            </span>

            <button
              onClick={handlePublishStandings}
              disabled={processing}
              className="flex items-center gap-2 px-6 py-2.5 bg-vsp-accent text-black font-black text-xs rounded-xl shadow-lg hover:brightness-110 transition-all disabled:opacity-50"
            >
              <Send className="w-4 h-4" />
              <span>اعتماد ونشر الترتيب للموبايل 🚀</span>
            </button>
          </div>
        </div>
      ) : (
        /* ==================================================================== */
        /* MODE 2: PUBLISHED STANDINGS VIEW (جدول الترتيب المنشور الحالي) */
        /* ==================================================================== */
        <>
          {/* Tabs */}
          <div className="flex items-center gap-2 border-b border-vsp-border">
            <button
              onClick={() => setActiveTab('standings')}
              className={`flex items-center gap-2 px-4 py-3 text-xs font-bold border-b-2 transition-all ${
                activeTab === 'standings'
                  ? 'border-vsp-accent text-vsp-accent'
                  : 'border-transparent text-vsp-textSecondary hover:text-white'
              }`}
            >
              <Trophy className="w-4 h-4" />
              <span>جدول الترتيب المنشور الحالي ({players.length})</span>
            </button>

            <button
              onClick={() => setActiveTab('registrations')}
              className={`flex items-center gap-2 px-4 py-3 text-xs font-bold border-b-2 transition-all ${
                activeTab === 'registrations'
                  ? 'border-vsp-accent text-vsp-accent'
                  : 'border-transparent text-vsp-textSecondary hover:text-white'
              }`}
            >
              <UserPlus className="w-4 h-4" />
              <span>طلبات الانضمام المعلقة ({registrations.length})</span>
            </button>
          </div>

          {/* Tab 1: Standings */}
          {activeTab === 'standings' && (
            <div className="bg-vsp-surface border border-vsp-border rounded-2xl overflow-hidden shadow-xl">
              {players.length === 0 ? (
                <EmptyState
                  icon={Trophy}
                  title="لا يوجد ترتيب منشور حالياً"
                  subtitle="اضغط على 'بدء بطولة جديدة' أو 'شيت رصد الدرجات' لإدخال نتائج البطولة ونشرها."
                  action={
                    <button
                      onClick={() => setShowNewTournamentModal(true)}
                      className="mt-3 px-4 py-2 bg-vsp-accent text-black font-bold text-xs rounded-xl"
                    >
                      بدء بطولة جديدة الآن
                    </button>
                  }
                />
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-right text-xs">
                    <thead className="bg-vsp-card/60 text-vsp-textSecondary border-b border-vsp-border">
                      <tr>
                        <th className="px-6 py-4 font-bold text-center w-16">#</th>
                        <th className="px-6 py-4 font-bold">اللاعب</th>
                        <th className="px-6 py-4 font-bold text-center">مجموع النقاط</th>
                        <th className="px-6 py-4 font-bold text-center">تدخل صحيح (تاكلينج) 🛡️</th>
                        <th className="px-6 py-4 font-bold text-center">أهداف ⚽</th>
                        <th className="px-6 py-4 font-bold text-center">مهارة ⚡</th>
                        <th className="px-6 py-4 font-bold text-center">الحالة</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-vsp-border/50">
                      {players.map((player, index) => {
                        const isTop1 = index === 0;
                        const isTop2 = index === 1;
                        const isTop3 = index === 2;

                        return (
                          <tr
                            key={player.id}
                            className={`hover:bg-vsp-card/30 transition-colors ${
                              isTop1 ? 'bg-vsp-accent/5' : ''
                            }`}
                          >
                            <td className="px-6 py-4 text-center font-black text-sm">
                              {isTop1 ? (
                                <span className="text-vsp-accent font-black text-base flex items-center justify-center gap-1">
                                  <Trophy className="w-4 h-4 inline" /> 1
                                </span>
                              ) : isTop2 ? (
                                <span className="text-zinc-300 font-bold text-sm">2</span>
                              ) : isTop3 ? (
                                <span className="text-amber-600 font-bold text-sm">3</span>
                              ) : (
                                <span className="text-zinc-500 font-mono">{index + 1}</span>
                              )}
                            </td>

                            <td className="px-6 py-4">
                              <div className="flex items-center gap-3">
                                <div className="w-9 h-9 rounded-xl bg-vsp-card border border-vsp-border flex items-center justify-center font-bold text-white shrink-0 overflow-hidden">
                                  {player.avatar_url ? (
                                    <img
                                      src={player.avatar_url}
                                      alt=""
                                      className="w-full h-full object-cover"
                                    />
                                  ) : (
                                    player.name?.charAt(0) || 'P'
                                  )}
                                </div>
                                <div>
                                  <h4 className="font-bold text-white flex items-center gap-1.5">
                                    <span>{player.name}</span>
                                    {isTop1 && <Flame className="w-3.5 h-3.5 text-vsp-accent fill-vsp-accent" />}
                                  </h4>
                                </div>
                              </div>
                            </td>

                            {/* Total Points */}
                            <td className="px-6 py-4 text-center">
                              <span className="text-sm font-black text-vsp-accent">
                                {player.total_points || 0} pts
                              </span>
                            </td>

                            {/* Tackles */}
                            <td className="px-6 py-4 text-center font-bold text-white">
                              {player.tackles || 0}
                            </td>

                            {/* Goals */}
                            <td className="px-6 py-4 text-center font-bold text-white">
                              {player.goals || 0}
                            </td>

                            {/* Skill points */}
                            <td className="px-6 py-4 text-center font-bold text-white">
                              {player.skill_points || 0}
                            </td>

                            {/* Badge */}
                            <td className="px-6 py-4 text-center">
                              {isTop1 ? (
                                <Badge variant="accent" size="xs">
                                  بطل البطولة 👑
                                </Badge>
                              ) : isTop2 || isTop3 ? (
                                <Badge variant="default" size="xs">
                                  منصة التتويج 🎖️
                                </Badge>
                              ) : (
                                <span className="text-zinc-500 text-xs">مصنف</span>
                              )}
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          )}

          {/* Tab 2: Registrations */}
          {activeTab === 'registrations' && (
            <div className="bg-vsp-surface border border-vsp-border rounded-2xl overflow-hidden shadow-xl">
              {registrations.length === 0 ? (
                <EmptyState
                  icon={UserPlus}
                  title="لا توجد طلبات انضمام معلقة حالياً"
                  subtitle="عندما يسجل اللاعبون عبر تطبيق الموبايل ستظهر طلباتهم هنا للاعتماد."
                />
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-right text-xs">
                    <thead className="bg-vsp-card/60 text-vsp-textSecondary border-b border-vsp-border">
                      <tr>
                        <th className="px-6 py-4 font-bold">اللاعب</th>
                        <th className="px-6 py-4 font-bold">الهاتف</th>
                        <th className="px-6 py-4 font-bold">تاريخ التقديم</th>
                        <th className="px-6 py-4 font-bold text-center">الإجراءات</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-vsp-border/50">
                      {registrations.map((reg) => {
                        const playerName = reg.player_name || reg.name || reg.users?.name || 'متقدم جديد';
                        const playerPhone = reg.phone || reg.users?.phone || '-';

                        return (
                          <tr key={reg.id} className="hover:bg-vsp-card/30 transition-colors">
                            <td className="px-6 py-4 font-bold text-white">{playerName}</td>
                            <td className="px-6 py-4 text-zinc-400 font-mono">{playerPhone}</td>
                            <td className="px-6 py-4 text-zinc-400 font-mono">
                              {new Date(reg.created_at).toLocaleDateString('ar-EG')}
                            </td>
                            <td className="px-6 py-4 text-center">
                              <div className="flex items-center justify-center gap-2">
                                <button
                                  onClick={() => approveReg(reg)}
                                  disabled={processing}
                                  className="flex items-center gap-1 px-3 py-1.5 bg-emerald-500/15 hover:bg-emerald-500/25 border border-emerald-500/30 text-emerald-400 rounded-lg font-bold text-xs transition-all"
                                >
                                  <CheckCircle2 className="w-3.5 h-3.5" />
                                  <span>قبول</span>
                                </button>
                                <button
                                  onClick={() => rejectReg(reg.id)}
                                  disabled={processing}
                                  className="flex items-center gap-1 px-3 py-1.5 bg-red-500/15 hover:bg-red-500/25 border border-red-500/30 text-red-400 rounded-lg font-bold text-xs transition-all"
                                >
                                  <XCircle className="w-3.5 h-3.5" />
                                  <span>رفض</span>
                                </button>
                              </div>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          )}
        </>
      )}

      {/* ==================================================================== */}
      {/* MODAL: START NEW TOURNAMENT (تحديد عدد اللاعبين يدوياً) */}
      {/* ==================================================================== */}
      <Modal
        isOpen={showNewTournamentModal}
        onClose={() => setShowNewTournamentModal(false)}
        title="بدء بطولة 1vs1 جديدة 🏆"
      >
        <form onSubmit={handleConfirmStartTournament} className="space-y-4 text-right" dir="rtl">
          <div className="p-3.5 bg-amber-500/10 border border-amber-500/30 rounded-xl text-amber-300 text-xs leading-relaxed">
            ⚠️ <strong>تنبيه:</strong> بدء بطولة جديدة سيقوم بتصفير جدول الترتيب السابق، وتجهيز شيت رصد جديد بالعدد الذي تحدده لتدخل فيه الدرجات دفعة واحدة بعد انتهاء الساعتين.
          </div>

          <div>
            <label className="block text-xs font-bold text-zinc-300 mb-1.5">
              اسم / عنوان البطولة
            </label>
            <input
              type="text"
              value={tournamentName}
              onChange={(e) => setTournamentName(e.target.value)}
              placeholder="مثال: بطولة الجمعة 1vs1"
              className="w-full bg-vsp-card border border-vsp-border rounded-xl px-4 py-2.5 text-white font-bold text-xs focus:border-vsp-accent focus:outline-none"
              required
            />
          </div>

          <div>
            <label className="block text-xs font-bold text-zinc-300 mb-1.5">
              عدد اللاعبين المشاركين (اكتب العدد المطلوب يدوياً)
            </label>
            <input
              type="number"
              min="2"
              max="128"
              value={playerCountInput}
              onChange={(e) => setPlayerCountInput(e.target.value)}
              placeholder="اكتب عدد اللاعبين (مثال: 8، 12، 16، 24، 32)"
              className="w-full bg-vsp-card border border-vsp-border rounded-xl px-4 py-2.5 text-white font-black text-sm focus:border-vsp-accent focus:outline-none"
              required
            />
            <span className="text-[11px] text-zinc-400 mt-1 block">
              سيتم إنشاء شيت رصد يحتوي على هذا العدد من الصفوف جاهزاً للكتابة فوراً.
            </span>
          </div>

          <div className="flex items-center justify-end gap-3 pt-4 border-t border-vsp-border">
            <button
              type="button"
              onClick={() => setShowNewTournamentModal(false)}
              className="px-4 py-2 bg-vsp-card hover:bg-vsp-surface border border-vsp-border text-white text-xs font-bold rounded-xl"
            >
              إلغاء
            </button>
            <button
              type="submit"
              disabled={processing}
              className="flex items-center gap-2 px-5 py-2 bg-amber-500 hover:bg-amber-400 text-black font-black text-xs rounded-xl shadow-lg transition-all"
            >
              {processing && <Loader2 className="w-4 h-4 animate-spin" />}
              <span>تأكيد وبدء البطولة 🚀</span>
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
};
"""

target_path = r'K:\.gemini\antigravity\scratch\vsp_admin_panel\src\pages\League1v1Page.jsx'
with open(target_path, 'w', encoding='utf-8') as f:
    f.write(code)

print("League1v1Page.jsx updated successfully!")

import os

content = '''import React, { useState, useEffect } from 'react';
import { 
  Trophy, 
  Users, 
  Plus, 
  Trash2, 
  Save, 
  Send, 
  CheckCircle2, 
  AlertTriangle, 
  History, 
  UserPlus, 
  Loader2, 
  Sparkles, 
  Shield, 
  Goal, 
  Zap, 
  RefreshCw,
  Eye,
  Check,
  X,
  XCircle
} from 'lucide-react';
import { adminService } from '../services/adminService';
import { supabase } from '../lib/supabase';
import Badge from '../components/ui/Badge';
import Modal from '../components/ui/Modal';
import EmptyState from '../components/ui/EmptyState';

export const League1v1Page = () => {
  const [activeTab, setActiveTab] = useState('live'); // 'live' | 'history' | 'registrations'
  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState(false);
  const [alert, setAlert] = useState(null); // { type: 'success' | 'error', message: string }

  // Active Tournament State
  const [activeTournament, setActiveTournament] = useState(null);
  const [players, setPlayers] = useState([]);

  // Modal State for New Tournament
  const [showNewModal, setShowNewModal] = useState(false);
  const [tournamentName, setTournamentName] = useState('');
  const [playerCountInput, setPlayerCountInput] = useState('8');

  // History & Registrations State
  const [historyList, setHistoryList] = useState([]);
  const [registrations, setRegistrations] = useState([]);
  const [viewHistoryModal, setViewHistoryModal] = useState(false);
  const [selectedHistoryTournament, setSelectedHistoryTournament] = useState(null);
  const [historyPlayers, setHistoryPlayers] = useState([]);

  // Auto-clear alert after 6 seconds
  useEffect(() => {
    if (alert) {
      const timer = setTimeout(() => setAlert(null), 6000);
      return () => clearTimeout(timer);
    }
  }, [alert]);

  const loadData = async () => {
    try {
      setLoading(true);
      
      // 1. Fetch current active or latest tournament
      const res = await adminService.getActiveOrLatest1v1Tournament();
      if (res.success) {
        setActiveTournament(res.tournament);
        setPlayers(res.players || []);
      }

      // 2. Fetch history list
      const histRes = await adminService.list1v1Tournaments();
      if (histRes.success) {
        setHistoryList(histRes.tournaments || []);
      }

      // 3. Fetch registrations
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

  useEffect(() => {
    loadData();
  }, []);

  // -------------------------------------------------------------------------
  // 1. START NEW TOURNAMENT (تحديد عدد اللاعبين يدوياً)
  // -------------------------------------------------------------------------
  const handleOpenNewTournamentModal = () => {
    const today = new Date().toLocaleDateString('ar-EG', {
      weekday: 'long',
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
    setTournamentName(`بطولة 1vs1 فردية - ${today}`);
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

      // Create new draft tournament
      const createRes = await adminService.create1v1Tournament({
        name: tournamentName,
        target_player_count: count,
        created_by: adminUserId,
      });

      if (!createRes.success) {
        throw new Error(createRes.error || 'فشل إنشاء البطولة');
      }

      const newTournament = createRes.data;

      // Pre-fill initial player rows
      const initialPlayers = Array.from({ length: count }, (_, i) => ({
        id: `temp_${Date.now()}_${i}`,
        player_name: `لاعب #${i + 1}`,
        name: `لاعب #${i + 1}`,
        tackles: 0,
        goals: 0,
        skills: 0,
        skill_points: 0,
        total_points: 0,
        user_id: null,
        avatar_url: '',
      }));

      // Save initial draft rows in database
      await adminService.save1v1TournamentPlayers(newTournament.id, initialPlayers);

      setActiveTournament(newTournament);
      setPlayers(initialPlayers);
      setShowNewModal(false);
      setAlert({
        type: 'success',
        message: `تم إنشاء البطولة بنجاح! شيت الرصد مجهز بـ (${count}) لاعبين وجاهز لتفريغ النقاط.`,
      });

      // Refresh list
      const histRes = await adminService.list1v1Tournaments();
      if (histRes.success) setHistoryList(histRes.tournaments || []);
    } catch (e) {
      console.error('Error starting new tournament:', e);
      setAlert({ type: 'error', message: 'فشل بدء البطولة: ' + e.message });
    } finally {
      setProcessing(false);
    }
  };

  // -------------------------------------------------------------------------
  // 2. LIVE SCORING SHEET ROW ACTIONS
  // -------------------------------------------------------------------------
  const handlePlayerChange = (index, field, value) => {
    setPlayers((prev) => {
      const updated = [...prev];
      const row = { ...updated[index] };

      if (field === 'player_name') {
        row.player_name = value;
        row.name = value;
      } else {
        const numVal = Math.max(0, parseInt(value) || 0);
        row[field] = numVal;
        if (field === 'skills') row.skill_points = numVal;
      }

      // Compute total_points live in frontend
      const t = Number(row.tackles) || 0;
      const g = Number(row.goals) || 0;
      const s = Number(row.skills ?? row.skill_points) || 0;
      row.total_points = t + g + s;

      updated[index] = row;
      return updated;
    });
  };

  const handleAddPlayerRow = () => {
    setPlayers((prev) => [
      ...prev,
      {
        id: `temp_${Date.now()}_${prev.length}`,
        player_name: `لاعب #${prev.length + 1}`,
        name: `لاعب #${prev.length + 1}`,
        tackles: 0,
        goals: 0,
        skills: 0,
        skill_points: 0,
        total_points: 0,
        user_id: null,
        avatar_url: '',
      },
    ]);
  };

  const handleDeletePlayerRow = (index) => {
    if (players.length <= 2) {
      setAlert({ type: 'error', message: 'يجب أن تحتوي البطولة على لاعبين اثنين على الأقل.' });
      return;
    }
    setPlayers((prev) => prev.filter((_, i) => i !== index));
  };

  // -------------------------------------------------------------------------
  // 3. SAVE DRAFT (حفظ كمسودة دون نشر)
  // -------------------------------------------------------------------------
  const handleSaveDraft = async () => {
    if (!activeTournament?.id) {
      setAlert({ type: 'error', message: 'لا توجد بطولة نشطة للحفظ.' });
      return;
    }

    try {
      setProcessing(true);
      const res = await adminService.save1v1TournamentPlayers(activeTournament.id, players);
      if (!res.success) throw new Error(res.error || 'فشل حفظ المسودة');

      setAlert({ type: 'success', message: 'تم حفظ مسودة درجات اللاعبين بنجاح! ✅' });
    } catch (e) {
      console.error('Error saving draft:', e);
      setAlert({ type: 'error', message: 'فشل حفظ المسودة: ' + e.message });
    } finally {
      setProcessing(false);
    }
  };

  // -------------------------------------------------------------------------
  // 4. PUBLISH TOURNAMENT (نشر الترتيب عبر الفانكشن الذري)
  // -------------------------------------------------------------------------
  const handlePublishTournament = async () => {
    if (!activeTournament?.id) {
      setAlert({ type: 'error', message: 'لا توجد بطولة نشطة للنشر.' });
      return;
    }

    const confirmMsg = `هل أنت متأكد من رغبتك في نشر الترتيب النهائي للبطولة (${activeTournament.name})؟\\n\\nسيتم أرشفة أي بطولة سابقة ونشر هذا الترتيب فوراً على تطبيق الموبايل لجميع اللاعبين!`;
    if (!window.confirm(confirmMsg)) return;

    try {
      setProcessing(true);

      // Step 1: Save current players to ensure table is 100% up to date
      const saveRes = await adminService.save1v1TournamentPlayers(activeTournament.id, players);
      if (!saveRes.success) throw new Error(saveRes.error || 'فشل حفظ اللاعبين قبل النشر');

      // Step 2: Call the atomic RPC function: publish_1v1_tournament_atomic
      const pubRes = await adminService.publish1v1Tournament(activeTournament.id);
      if (!pubRes.success) {
        throw new Error(pubRes.error || 'فشل نشر البطولة');
      }

      setAlert({
        type: 'success',
        message: '🏆 تم حفظ ونشر الترتيب النهائي بنجاح! الترتيب معروض الآن مباشرة على هواتف اللاعبين.',
      });

      // Reload updated tournament and players
      await loadData();
    } catch (e) {
      console.error('Error publishing tournament:', e);
      setAlert({ type: 'error', message: 'فشل النشر: ' + e.message });
    } finally {
      setProcessing(false);
    }
  };

  // -------------------------------------------------------------------------
  // 5. VIEW ARCHIVE DETAILS
  // -------------------------------------------------------------------------
  const handleViewArchive = async (tourn) => {
    try {
      setSelectedHistoryTournament(tourn);
      setViewHistoryModal(true);
      const { data, error } = await supabase
        .from('vsp_1v1_tournament_players')
        .select('*')
        .eq('tournament_id', tourn.id)
        .order('total_points', { ascending: false });

      if (error) throw error;
      setHistoryPlayers(data || []);
    } catch (e) {
      console.error('Error fetching archive players:', e);
    }
  };

  // Sorted list for live ranking preview
  const sortedPlayersPreview = [...players].sort((a, b) => {
    const ptA = (Number(a.tackles) || 0) + (Number(a.goals) || 0) + (Number(a.skills ?? a.skill_points) || 0);
    const ptB = (Number(b.tackles) || 0) + (Number(b.goals) || 0) + (Number(b.skills ?? b.skill_points) || 0);
    return ptB - ptA;
  });

  return (
    <div className="p-6 space-y-6 text-right max-w-7xl mx-auto" dir="rtl">
      {/* ==================================================================== */}
      {/* HEADER SECTION */}
      {/* ==================================================================== */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-vsp-surface p-6 rounded-2xl border border-vsp-border shadow-xl">
        <div>
          <div className="flex items-center gap-3 mb-1">
            <span className="p-2.5 bg-amber-500/10 border border-amber-500/30 rounded-xl text-amber-400">
              <Trophy className="w-7 h-7" />
            </span>
            <div>
              <h1 className="text-2xl font-black text-white">إدارة بطولة المواجهات الفردية (1vs1)</h1>
              <p className="text-xs text-vsp-textSecondary mt-0.5">
                إدارة النسخ الواقعية، الرصد السريع للنقاط من الورقة، والنشر الذري المباشر على الهواتف.
              </p>
            </div>
          </div>
        </div>

        {/* Action Controls */}
        <div className="flex items-center gap-3">
          <button
            onClick={loadData}
            disabled={loading || processing}
            className="p-2.5 bg-vsp-card hover:bg-vsp-border border border-vsp-border text-zinc-400 hover:text-white rounded-xl transition-all"
            title="تحديث البيانات"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          </button>

          <button
            onClick={handleOpenNewTournamentModal}
            disabled={processing}
            className="flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-amber-500 to-amber-600 hover:from-amber-400 hover:to-amber-500 text-black font-black text-xs rounded-xl shadow-lg shadow-amber-500/20 transition-all active:scale-95"
          >
            <Plus className="w-4 h-4 stroke-[3]" />
            <span>بدء بطولة جديدة</span>
          </button>
        </div>
      </div>

      {/* ==================================================================== */}
      {/* ALERT BANNER */}
      {/* ==================================================================== */}
      {alert && (
        <div
          className={`p-4 rounded-xl flex items-center justify-between gap-3 border transition-all ${
            alert.type === 'success'
              ? 'bg-emerald-500/15 border-emerald-500/30 text-emerald-300'
              : 'bg-red-500/15 border-red-500/30 text-red-300'
          }`}
        >
          <div className="flex items-center gap-2 text-xs font-bold">
            {alert.type === 'success' ? (
              <CheckCircle2 className="w-5 h-5 text-emerald-400 flex-shrink-0" />
            ) : (
              <AlertTriangle className="w-5 h-5 text-red-400 flex-shrink-0" />
            )}
            <span>{alert.message}</span>
          </div>
          <button onClick={() => setAlert(null)} className="p-1 hover:opacity-80">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* ==================================================================== */}
      {/* TABS */}
      {/* ==================================================================== */}
      <div className="flex border-b border-vsp-border gap-2">
        <button
          onClick={() => setActiveTab('live')}
          className={`pb-3 px-4 text-xs font-bold flex items-center gap-2 transition-all relative ${
            activeTab === 'live'
              ? 'text-vsp-accent border-b-2 border-vsp-accent'
              : 'text-vsp-textSecondary hover:text-white'
          }`}
        >
          <Trophy className="w-4 h-4" />
          <span>شيت الرصد والبطولة الحالية</span>
          {activeTournament?.status === 'published' && (
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
          )}
        </button>

        <button
          onClick={() => setActiveTab('history')}
          className={`pb-3 px-4 text-xs font-bold flex items-center gap-2 transition-all relative ${
            activeTab === 'history'
              ? 'text-vsp-accent border-b-2 border-vsp-accent'
              : 'text-vsp-textSecondary hover:text-white'
          }`}
        >
          <History className="w-4 h-4" />
          <span>أرشيف البطولات السابقة ({historyList.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('registrations')}
          className={`pb-3 px-4 text-xs font-bold flex items-center gap-2 transition-all relative ${
            activeTab === 'registrations'
              ? 'text-vsp-accent border-b-2 border-vsp-accent'
              : 'text-vsp-textSecondary hover:text-white'
          }`}
        >
          <UserPlus className="w-4 h-4" />
          <span>طلبات الانضمام المعلقة</span>
          {registrations.length > 0 && (
            <span className="px-2 py-0.5 bg-vsp-accent text-black font-black text-[10px] rounded-full">
              {registrations.length}
            </span>
          )}
        </button>
      </div>

      {/* ==================================================================== */}
      {/* TAB 1: LIVE BULK SCORING SHEET */}
      {/* ==================================================================== */}
      {activeTab === 'live' && (
        <div className="space-y-6">
          {loading ? (
            <div className="p-16 flex flex-col items-center justify-center gap-3 bg-vsp-surface border border-vsp-border rounded-2xl">
              <Loader2 className="w-8 h-8 text-vsp-accent animate-spin" />
              <span className="text-xs text-vsp-textSecondary font-bold">جاري تحميل بيانات البطولة...</span>
            </div>
          ) : !activeTournament ? (
            <EmptyState
              icon={Trophy}
              title="لا توجد أي بطولة تم إنشاؤها بعد"
              subtitle="اضغط على زر 'بدء بطولة جديدة' بالأعلى لتحديد اسم البطولة وعدد اللاعبين والبدء في الرصد."
            />
          ) : (
            <>
              {/* Active Tournament Status Card */}
              <div className="bg-vsp-surface border border-vsp-border rounded-2xl p-5 shadow-lg flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div>
                  <div className="flex items-center gap-3">
                    <h2 className="text-lg font-black text-white">{activeTournament.name}</h2>
                    {activeTournament.status === 'published' ? (
                      <Badge variant="accent" size="sm">
                        منشورة على التطبيق مباشرة 🟢
                      </Badge>
                    ) : activeTournament.status === 'draft' ? (
                      <Badge variant="warning" size="sm">
                        مسودة قيد الإدخال (Draft) ✍️
                      </Badge>
                    ) : (
                      <Badge variant="default" size="sm">
                        مؤرشفة (Archived) 📁
                      </Badge>
                    )}
                  </div>
                  <div className="flex items-center gap-4 text-xs text-zinc-400 mt-2">
                    <span>
                      🎯 عدد اللاعبين المستهدف:{' '}
                      <strong className="text-white">{activeTournament.target_player_count || players.length}</strong>
                    </span>
                    <span>•</span>
                    <span>
                      📅 تم الإنشاء:{' '}
                      <strong className="text-white">
                        {new Date(activeTournament.created_at).toLocaleDateString('ar-EG')}
                      </strong>
                    </span>
                    {activeTournament.published_at && (
                      <>
                        <span>•</span>
                        <span>
                          🚀 نُشرت في:{' '}
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

                {/* Bulk Save & Publish Controls */}
                <div className="flex items-center gap-3">
                  <button
                    onClick={handleSaveDraft}
                    disabled={processing}
                    className="flex items-center gap-2 px-4 py-2.5 bg-vsp-card hover:bg-vsp-border border border-vsp-border text-white text-xs font-bold rounded-xl transition-all"
                  >
                    <Save className="w-4 h-4 text-zinc-400" />
                    <span>حفظ كمسودة</span>
                  </button>

                  <button
                    onClick={handlePublishTournament}
                    disabled={processing}
                    className="flex items-center gap-2 px-6 py-2.5 bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-400 hover:to-teal-500 text-black font-black text-xs rounded-xl shadow-lg shadow-emerald-500/20 transition-all active:scale-95"
                  >
                    {processing ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                      <Send className="w-4 h-4 stroke-[2.5]" />
                    )}
                    <span>حفظ ونشر الترتيب النهائي 🏆</span>
                  </button>
                </div>
              </div>

              {/* Scoring Formula Info Banner */}
              <div className="p-4 bg-amber-500/10 border border-amber-500/25 rounded-xl flex items-center justify-between gap-4 text-xs">
                <div className="flex items-center gap-3 text-amber-300 font-bold">
                  <Sparkles className="w-5 h-5 text-amber-400 flex-shrink-0" />
                  <span>
                    معادلة رصد النقاط الواقعية: المجموع = [تدخل صحيح (تاكلينج) × 1] + [أهداف × 1] + [مهارات × 1].
                  </span>
                </div>
                <button
                  onClick={handleAddPlayerRow}
                  className="flex items-center gap-1.5 px-3 py-1.5 bg-amber-500/20 hover:bg-amber-500/30 border border-amber-500/30 text-amber-300 font-bold text-xs rounded-lg transition-all"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>إضافة لاعب إضافي</span>
                </button>
              </div>

              {/* Live Bulk Scoring Table */}
              <div className="bg-vsp-surface border border-vsp-border rounded-2xl overflow-hidden shadow-xl">
                <div className="overflow-x-auto">
                  <table className="w-full text-right text-xs">
                    <thead className="bg-vsp-card/70 text-vsp-textSecondary border-b border-vsp-border">
                      <tr>
                        <th className="px-5 py-4 font-bold text-center w-14">#</th>
                        <th className="px-5 py-4 font-bold min-w-[200px]">اسم اللاعب</th>
                        <th className="px-5 py-4 font-bold text-center min-w-[110px]">
                          <div className="flex items-center justify-center gap-1 text-cyan-400">
                            <Shield className="w-3.5 h-3.5" />
                            <span>تاكلينج (+1)</span>
                          </div>
                        </th>
                        <th className="px-5 py-4 font-bold text-center min-w-[110px]">
                          <div className="flex items-center justify-center gap-1 text-emerald-400">
                            <Goal className="w-3.5 h-3.5" />
                            <span>أهداف (+1)</span>
                          </div>
                        </th>
                        <th className="px-5 py-4 font-bold text-center min-w-[110px]">
                          <div className="flex items-center justify-center gap-1 text-purple-400">
                            <Zap className="w-3.5 h-3.5" />
                            <span>مهارات (+1)</span>
                          </div>
                        </th>
                        <th className="px-5 py-4 font-black text-center min-w-[120px] text-amber-400">
                          المجموع (تلقائي)
                        </th>
                        <th className="px-5 py-4 font-bold text-center w-24">إجراءات</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-vsp-border/40">
                      {players.map((p, idx) => {
                        const total = (Number(p.tackles) || 0) + (Number(p.goals) || 0) + (Number(p.skills ?? p.skill_points) || 0);
                        const isTop = idx === 0 && total > 0;

                        return (
                          <tr key={p.id || idx} className="hover:bg-vsp-card/30 transition-colors">
                            {/* Row Index */}
                            <td className="px-5 py-3.5 text-center font-mono font-bold text-zinc-500">
                              {idx + 1}
                            </td>

                            {/* Player Name */}
                            <td className="px-5 py-3.5">
                              <input
                                type="text"
                                value={p.player_name || p.name || ''}
                                onChange={(e) => handlePlayerChange(idx, 'player_name', e.target.value)}
                                placeholder={`اسم اللاعب #${idx + 1}`}
                                className="w-full bg-vsp-card border border-vsp-border rounded-xl px-3.5 py-2 text-white font-bold text-xs focus:border-vsp-accent focus:outline-none transition-all"
                              />
                            </td>

                            {/* Tackles Input */}
                            <td className="px-5 py-3.5 text-center">
                              <input
                                type="number"
                                min="0"
                                value={p.tackles || 0}
                                onChange={(e) => handlePlayerChange(idx, 'tackles', e.target.value)}
                                className="w-20 bg-vsp-card border border-cyan-500/30 rounded-xl px-2.5 py-2 text-center text-cyan-300 font-black text-xs focus:border-cyan-400 focus:outline-none"
                              />
                            </td>

                            {/* Goals Input */}
                            <td className="px-5 py-3.5 text-center">
                              <input
                                type="number"
                                min="0"
                                value={p.goals || 0}
                                onChange={(e) => handlePlayerChange(idx, 'goals', e.target.value)}
                                className="w-20 bg-vsp-card border border-emerald-500/30 rounded-xl px-2.5 py-2 text-center text-emerald-300 font-black text-xs focus:border-emerald-400 focus:outline-none"
                              />
                            </td>

                            {/* Skills Input */}
                            <td className="px-5 py-3.5 text-center">
                              <input
                                type="number"
                                min="0"
                                value={p.skills ?? p.skill_points ?? 0}
                                onChange={(e) => handlePlayerChange(idx, 'skills', e.target.value)}
                                className="w-20 bg-vsp-card border border-purple-500/30 rounded-xl px-2.5 py-2 text-center text-purple-300 font-black text-xs focus:border-purple-400 focus:outline-none"
                              />
                            </td>

                            {/* Auto Total Points Display */}
                            <td className="px-5 py-3.5 text-center">
                              <span className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-amber-500/15 border border-amber-500/30 text-amber-300 rounded-xl font-black text-sm">
                                {isTop && <span>👑</span>}
                                <span>{total}</span>
                                <span className="text-[10px] text-amber-400/70 font-normal">نقطة</span>
                              </span>
                            </td>

                            {/* Delete Row Button */}
                            <td className="px-5 py-3.5 text-center">
                              <button
                                onClick={() => handleDeletePlayerRow(idx)}
                                title="حذف هذا اللاعب"
                                className="p-2 text-zinc-500 hover:text-red-400 hover:bg-red-500/10 rounded-lg transition-all"
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

                {/* Bottom Add Row Bar */}
                <div className="p-4 bg-vsp-card/40 border-t border-vsp-border flex items-center justify-between">
                  <button
                    onClick={handleAddPlayerRow}
                    className="flex items-center gap-2 px-4 py-2 bg-vsp-surface hover:bg-vsp-border border border-vsp-border text-white text-xs font-bold rounded-xl transition-all"
                  >
                    <Plus className="w-4 h-4 text-vsp-accent" />
                    <span>إضافة صف لاعب جديد</span>
                  </button>

                  <span className="text-xs text-zinc-400 font-bold">
                    إجمالي اللاعبين المسجلين في الشيت: <span className="text-white">{players.length}</span>
                  </span>
                </div>
              </div>
            </>
          )}
        </div>
      )}

      {/* ==================================================================== */}
      {/* TAB 2: HISTORY / ARCHIVE */}
      {/* ==================================================================== */}
      {activeTab === 'history' && (
        <div className="bg-vsp-surface border border-vsp-border rounded-2xl overflow-hidden shadow-xl">
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
                    <th className="px-6 py-4 font-bold text-center">الحالة</th>
                    <th className="px-6 py-4 font-bold text-center">العدد المستهدف</th>
                    <th className="px-6 py-4 font-bold">تاريخ الإنشاء</th>
                    <th className="px-6 py-4 font-bold">تاريخ النشر</th>
                    <th className="px-6 py-4 font-bold text-center">الإجراءات</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-vsp-border/50">
                  {historyList.map((item) => (
                    <tr key={item.id} className="hover:bg-vsp-card/30 transition-colors">
                      <td className="px-6 py-4 font-bold text-white">{item.name}</td>
                      <td className="px-6 py-4 text-center">
                        {item.status === 'published' ? (
                          <Badge variant="accent" size="xs">
                            منشورة حالياً 🟢
                          </Badge>
                        ) : item.status === 'draft' ? (
                          <Badge variant="warning" size="xs">
                            مسودة ✍️
                          </Badge>
                        ) : (
                          <Badge variant="default" size="xs">
                            مؤرشفة 📁
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
                          <Eye className="w-3.5 h-3.5 text-vsp-accent" />
                          <span>عرض الترتيب</span>
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

      {/* ==================================================================== */}
      {/* TAB 3: REGISTRATIONS */}
      {/* ==================================================================== */}
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
                              onClick={async () => {
                                try {
                                  setProcessing(true);
                                  await adminService.approve1v1Registration({
                                    registrationId: reg.id,
                                    name: playerName,
                                  });
                                  setAlert({ type: 'success', message: 'تم قبول طلب اللاعب بنجاح!' });
                                  loadData();
                                } catch (e) {
                                  setAlert({ type: 'error', message: e.message });
                                } finally {
                                  setProcessing(false);
                                }
                              }}
                              disabled={processing}
                              className="flex items-center gap-1 px-3 py-1.5 bg-emerald-500/15 hover:bg-emerald-500/25 border border-emerald-500/30 text-emerald-400 rounded-lg font-bold text-xs transition-all"
                            >
                              <CheckCircle2 className="w-3.5 h-3.5" />
                              <span>قبول</span>
                            </button>
                            <button
                              onClick={async () => {
                                try {
                                  setProcessing(true);
                                  await adminService.reject1v1Registration(reg.id);
                                  setAlert({ type: 'success', message: 'تم رفض طلب اللاعب.' });
                                  loadData();
                                } catch (e) {
                                  setAlert({ type: 'error', message: e.message });
                                } finally {
                                  setProcessing(false);
                                }
                              }}
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

      {/* ==================================================================== */}
      {/* MODAL: START NEW TOURNAMENT (تحديد عدد اللاعبين يدوياً) */}
      {/* ==================================================================== */}
      <Modal
        isOpen={showNewModal}
        onClose={() => setShowNewModal(false)}
        title="بدء بطولة 1vs1 جديدة 🏆"
      >
        <form onSubmit={handleConfirmStartTournament} className="space-y-4 text-right" dir="rtl">
          <div className="p-3.5 bg-amber-500/10 border border-amber-500/30 rounded-xl text-amber-300 text-xs leading-relaxed">
            ⚠️ <strong>تنبيه:</strong> بدء بطولة جديدة سينشئ مسودة جديدة بشيت رصد فارغ بالعدد الذي تحدده بنفسك، ليتم تفريغ نقاط المباريات الورقية دفعة واحدة بعد انتهاء الساعتين.
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
              placeholder="اكتب عدد اللاعبين (مثال: 4، 8، 12، 16، 24)"
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
              onClick={() => setShowNewModal(false)}
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
              <span>تأكيد وإنشاء البطولة 🚀</span>
            </button>
          </div>
        </form>
      </Modal>

      {/* ==================================================================== */}
      {/* MODAL: VIEW ARCHIVED TOURNAMENT STANDINGS */}
      {/* ==================================================================== */}
      <Modal
        isOpen={viewHistoryModal}
        onClose={() => setViewHistoryModal(false)}
        title={`ترتيب: ${selectedHistoryTournament?.name || ''}`}
      >
        <div className="space-y-4 text-right" dir="rtl">
          <div className="overflow-x-auto max-h-[60vh]">
            <table className="w-full text-right text-xs">
              <thead className="bg-vsp-card/70 text-vsp-textSecondary border-b border-vsp-border sticky top-0">
                <tr>
                  <th className="px-4 py-3 font-bold text-center">المركز</th>
                  <th className="px-4 py-3 font-bold">اللاعب</th>
                  <th className="px-4 py-3 font-bold text-center">تاكلينج</th>
                  <th className="px-4 py-3 font-bold text-center">أهداف</th>
                  <th className="px-4 py-3 font-bold text-center">مهارة</th>
                  <th className="px-4 py-3 font-bold text-center text-amber-400">المجموع</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-vsp-border/50">
                {historyPlayers.map((p, idx) => (
                  <tr key={p.id} className="hover:bg-vsp-card/30">
                    <td className="px-4 py-3 text-center font-bold">
                      {idx === 0 ? '👑 #1' : `#${idx + 1}`}
                    </td>
                    <td className="px-4 py-3 font-bold text-white">{p.player_name}</td>
                    <td className="px-4 py-3 text-center text-cyan-400 font-bold">{p.tackles}</td>
                    <td className="px-4 py-3 text-center text-emerald-400 font-bold">{p.goals}</td>
                    <td className="px-4 py-3 text-center text-purple-400 font-bold">{p.skills}</td>
                    <td className="px-4 py-3 text-center font-black text-amber-400">{p.total_points}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="flex justify-end pt-3 border-t border-vsp-border">
            <button
              onClick={() => setViewHistoryModal(false)}
              className="px-4 py-2 bg-vsp-card hover:bg-vsp-surface border border-vsp-border text-white text-xs font-bold rounded-xl"
            >
              إغلاق
            </button>
          </div>
        </div>
      </Modal>
    </div>
  );
};
'''

dest_path = r'K:\.gemini\antigravity\scratch\vsp_admin_panel\src\pages\League1v1Page.jsx'
with open(dest_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('League1v1Page.jsx deployed successfully!')

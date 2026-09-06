import re

path = '../vsp_admin_panel/src/services/adminService.js'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

target = """  async markChampionshipPrizeDelivered(championshipId, notes = '') {
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
  }"""

new_methods = """  async markChampionshipPrizeDelivered(championshipId, notes = '') {
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

  async approveChampionship(championshipId) {
    try {
      const { data, error } = await this.client.rpc('admin_approve_championship_atomic', {
        p_championship_id: championshipId,
      });
      if (error) throw error;
      return { success: true, data };
    } catch (e) {
      console.error('Error in approveChampionship:', e);
      const err = classifyError(e);
      return { success: false, error: err.message, errorType: err.type };
    }
  }

  async rejectChampionship(championshipId, reason = '') {
    try {
      const { data, error } = await this.client.rpc('admin_reject_championship_atomic', {
        p_championship_id: championshipId,
        p_reason: reason,
      });
      if (error) throw error;
      return { success: true, data };
    } catch (e) {
      console.error('Error in rejectChampionship:', e);
      const err = classifyError(e);
      return { success: false, error: err.message, errorType: err.type };
    }
  }"""

if target in content:
    content = content.replace(target, new_methods)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Successfully patched adminService.js with approveChampionship and rejectChampionship")
else:
    print("Target not found in adminService.js!")

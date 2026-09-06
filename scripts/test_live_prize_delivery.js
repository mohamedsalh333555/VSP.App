import { adminService } from '../../vsp_admin_panel/src/services/adminService.js';
import { supabase } from '../../vsp_admin_panel/src/lib/supabase.js';

async function main() {
  console.log('='.repeat(75));
  console.log('LIVE TEST: CHAMPIONSHIP PRIZE DELIVERY HANDOVER VIA adminService.js');
  console.log('='.repeat(75));

  // 1. Authenticate with real Admin credentials
  console.log('Authenticating admin session with hana.ramadan@vsp.com...');
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email: 'hana.ramadan@vsp.com',
    password: 'Admin123456!',
  });

  if (authError) {
    console.error('Authentication failed:', authError);
    process.exit(1);
  }
  console.log(`Admin authenticated successfully: ${authData.user.email} (${authData.user.id})`);

  // 2. Setup a live test championship with status = completed and prize_pool = 1500.00
  const champId = crypto.randomUUID();
  const champName = `بطولة اختبار التسليم - ${champId.slice(0, 8)}`;

  console.log(`\nCreating test completed championship (ID: ${champId})...`);
  const { data: createData, error: createError } = await supabase
    .from('championships')
    .insert({
      id: champId,
      name: champName,
      type: 'tournament',
      sport_type: 'football',
      start_date: new Date().toISOString(),
      end_date: new Date(Date.now() + 7 * 86400000).toISOString(),
      entry_fee: 150.0,
      grand_prize: 1000.0,
      prize_pool: 1500.0,
      max_teams: 10,
      owner_id: authData.user.id,
      governorate: 'Cairo',
      status: 'completed',
      champion_team_name: 'فريق الأبطال التجريبي',
      winner_team_name: 'فريق الأبطال التجريبي',
      prize_delivered: false,
    })
    .select('id, name, status, prize_pool, prize_delivered')
    .single();

  if (createError) {
    console.error('Failed to create test championship:', createError);
    process.exit(1);
  }
  console.log('Championship created before delivery:', JSON.stringify(createData, null, 2));

  // 3. Invoke adminService.markChampionshipPrizeDelivered directly!
  const deliveryNotes = 'تم التسليم نقداً في الملعب بحضور الإدارة والشهود';
  console.log('\nInvoking adminService.markChampionshipPrizeDelivered(id, notes)...');
  const serviceResult = await adminService.markChampionshipPrizeDelivered(champId, deliveryNotes);
  console.log('Result returned from adminService:', JSON.stringify(serviceResult, null, 2));

  if (!serviceResult.success) {
    console.error('adminService.markChampionshipPrizeDelivered failed!', serviceResult);
    process.exit(1);
  }

  // 4. Query live database directly via Supabase client to verify updated fields
  console.log('\nQuerying championships row from live DB...');
  const { data: updatedChamp, error: fetchErr } = await supabase
    .from('championships')
    .select('id, name, status, prize_pool, prize_delivered, prize_delivered_at, prize_delivered_by, prize_delivery_notes')
    .eq('id', champId)
    .single();

  if (fetchErr) {
    console.error('Failed to query championship:', fetchErr);
    process.exit(1);
  }
  console.log('Championship state in DB after delivery:');
  console.log(JSON.stringify(updatedChamp, null, 2));

  // 5. Query transactions table to verify financial audit ledger entry
  console.log('\nQuerying transactions financial ledger from live DB...');
  const { data: txRecords, error: txErr } = await supabase
    .from('transactions')
    .select('id, championship_id, amount, type, status, description, metadata, created_at')
    .eq('championship_id', champId);

  if (txErr) {
    console.error('Failed to query transactions:', txErr);
  } else {
    console.log(`Found ${txRecords.length} transaction ledger records:`);
    console.log(JSON.stringify(txRecords, null, 2));
  }

  // 6. Test Double-Delivery Protection (should fail)
  console.log('\nTesting Double-Delivery Prevention: calling adminService again for same tournament...');
  const doubleDeliveryResult = await adminService.markChampionshipPrizeDelivered(champId, 'محاولة تسليم ثانية مكررة');
  console.log('Double Delivery Result:', JSON.stringify(doubleDeliveryResult, null, 2));
  if (doubleDeliveryResult.success === false || doubleDeliveryResult.data?.success === false) {
    console.log('Double delivery successfully blocked by atomic guard!');
  } else {
    console.error('WARNING: Double delivery was not blocked!');
  }

  // 7. Clean up all test data
  console.log('\nCleaning up test data...');
  await supabase.from('transactions').delete().eq('championship_id', champId);
  await supabase.from('championships').delete().eq('id', champId);

  // 8. Confirm Cleanup with count(*)
  const { count: champCount } = await supabase
    .from('championships')
    .select('*', { count: 'exact', head: true })
    .eq('id', champId);

  const { count: txCount } = await supabase
    .from('transactions')
    .select('*', { count: 'exact', head: true })
    .eq('championship_id', champId);

  console.log('\nCLEANUP VERIFICATION (Must be 0):');
  console.log(`  Championships remaining: ${champCount}`);
  console.log(`  Transactions remaining:  ${txCount}`);

  if (champCount === 0 && txCount === 0) {
    console.log('\nSUCCESS: 100% CLEAN DATABASE (count(*) = 0).');
  } else {
    console.error('Cleanup incomplete!');
  }
  console.log('='.repeat(75));
}

main().catch((err) => {
  console.error('Unhandled error in test:', err);
  process.exit(1);
});

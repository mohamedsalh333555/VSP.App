-- Emergency inverse only. Not a forward migration or automatic deployment.
-- Refuses unknown bodies; leaves the private unused helper in place.
DO $inverse$
DECLARE
 v_plan constant jsonb := $plan$[
  {
    "signature": "public.activate_vsp_pro(text,text,integer)",
    "before_sha256": "56ab619bdfadb99166f21e1fe91cc07c749a04be822a2fde3d4dc607250e545b",
    "after_sha256": "db04ae2e954c30168ab736f3bdfbcdbd0c9057ba2babdaf66dd2242a0bb867a3",
    "begin_offset": 57,
    "origins": [
      "production_lf"
    ]
  },
  {
    "signature": "public.activate_vsp_pro(text,text,integer)",
    "before_sha256": "5ef489f0a9101b0e5d15d8a8c1dc28da51c31be6e20430e16a8e523f0e57d84d",
    "after_sha256": "3a7a050f2ce859732e20fe2bd76d3e5a870215260520f1997631b7f9a1b07096",
    "begin_offset": 61,
    "origins": [
      "staging"
    ]
  },
  {
    "signature": "public.activate_vsp_pro(text,text,integer)",
    "before_sha256": "916f1453c9db8fd0647fac683649a3a68630d5b14e014aa47645dceb4b3e7c73",
    "after_sha256": "5e5a52248ca039b3e239fd8e71ece02d9c75d7716e26c504be70b02f148ff746",
    "begin_offset": 61,
    "origins": [
      "production"
    ]
  },
  {
    "signature": "public.admin_add_1v1_cash_player_atomic(uuid,text,uuid,numeric)",
    "before_sha256": "d56d74c8ab6b4761554148043c9a6dcfaf8938814bcd98ea15f7fcee54851dda",
    "after_sha256": "cf2d6fc84b9388e250d94287a462f7163250a2a69e151c4ed0084e8848a9884f",
    "begin_offset": 226,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_approve_1v1_registration_atomic(uuid,text,text)",
    "before_sha256": "6af7ad5fbe58d21ed7a570146738bdeb6f8e1099d68697196fa428977236b17e",
    "after_sha256": "a28b9bb00525d67827cf3640a82986c04b1125b78f94ec49794669add2386ec2",
    "begin_offset": 114,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_approve_championship_atomic(uuid)",
    "before_sha256": "b25c114dc8d11c8986e0ecf81602ca48ac6484ec226f48bef568abd26db4409e",
    "after_sha256": "ac65b06411903ca49998a9c1a273ca91ef69590bc48224c34a0ef5c132c219f0",
    "begin_offset": 118,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_approve_owner_atomic(uuid)",
    "before_sha256": "b49ac63e36696d4f4e1a37d13984fff4b96f854790a4833e776f5a0ae44013ae",
    "after_sha256": "7bb4bf02a520c7fe5c09787c785c868a583301f34d137f2860b848804bffc856",
    "begin_offset": 106,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_create_1v1_tournament_atomic(text,integer,numeric,timestamp with time zone,text,numeric)",
    "before_sha256": "3d779f1aa7b204838d2309a8a130dd1b99a47ad0e7166d01b345042e7cde3b67",
    "after_sha256": "ce62f2465a39d7dd9e032ca8834399c5b74e19ea6b4832b194760dcfe1e460de",
    "begin_offset": 144,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_create_owner_with_stadium_atomic(text,text,text,text,text,numeric)",
    "before_sha256": "9d183589aec0756a1f6bec99b9a211dbc1442aa259a4343d10c1474b445525e9",
    "after_sha256": "7241291aeebb3b537ada00d4f5b57bd7e9e71dd0f2a3f77b4dcef7366b983310",
    "begin_offset": 171,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_finalize_1v1_tournament_atomic(uuid,uuid)",
    "before_sha256": "5cb8d7c2e5e8097729264ec92b496fe65967da6a07ae9a0c88641601a16d63a7",
    "after_sha256": "174f32167337eaccfd34cb6ef001c5767538fef947efb08b78d1a5a1c25079d7",
    "begin_offset": 159,
    "origins": [
      "production"
    ]
  },
  {
    "signature": "public.admin_finalize_1v1_tournament_atomic(uuid,uuid)",
    "before_sha256": "c381774bc129c6abd733b648af4251c69ef890c02bf900d35b13146798026e6d",
    "after_sha256": "fbe18aab6f4ed3db0f0c12bf45180c2d60ef65393eab48368214048c27b33f75",
    "begin_offset": 159,
    "origins": [
      "staging"
    ]
  },
  {
    "signature": "public.admin_get_1v1_round_scores(uuid,integer)",
    "before_sha256": "15d68754c8b2ff79b7e97e1d7aeb08f75fe5c0a8b0d000cbfe4b5f6cf66565b4",
    "after_sha256": "9f89fad51a33a0d8dabf599be8810652d454592d159e8edd50e6767fcc0e8e31",
    "begin_offset": 45,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_publish_legacy_1v1_standings_atomic(jsonb)",
    "before_sha256": "7c79f8a2294934babdf6d0d74a30edaf7388804e12d15f4d72184e70141c7ce7",
    "after_sha256": "5d8e8e0bacdb5a595c965e475d7e7b365662aed06ae028cdc8902bf4ac84b049",
    "begin_offset": 233,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_record_payout_settlement_atomic(uuid,numeric,text,text)",
    "before_sha256": "e9f82467244d3eac5fca0961552db5522dc36c34e9f8bdebf49f92a4d8c5e0ef",
    "after_sha256": "8778d36506aa6255bc2e39afe2b762b44379ad18527502d75a6365f66504c114",
    "begin_offset": 225,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_register_owner_on_behalf(text,text,text,text,text)",
    "before_sha256": "a3972175089c62a9636c957a6426330e448d65291b8a2c567684e30b13e77add",
    "after_sha256": "90e4470955279285c19e72fb834e13a634b63561a9ea7054025cca5a2abd5100",
    "begin_offset": 58,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_reject_1v1_registration_atomic(uuid)",
    "before_sha256": "c26fe94098a7fe4c115c297cd4b8e06498a22c5dd6e3979a96f874d48b659386",
    "after_sha256": "02779cfe0a542d342b8764623738d7e7c5718bd3b2d58eba18bd65a1777430a4",
    "begin_offset": 69,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_reject_championship_atomic(uuid,text)",
    "before_sha256": "28be51b47eeb81c8381bbaf5d623ab6a3e4ba2e83d4a0d13e8589e7024374b9a",
    "after_sha256": "6a9bbd1733491e24313fa159c22deec862a400a422b7ce1493a4cbebcec108ac",
    "begin_offset": 118,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_reject_owner_atomic(uuid,text)",
    "before_sha256": "19240156ac7ffdcd89e79ff94228c66eb73a235ac9e217514d50d06b3c3e2fbb",
    "after_sha256": "943f5aeadf516e0d6a8d5d7ff160641e553a7d5d4330f4c4f840a0e95b0574b2",
    "begin_offset": 106,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_reset_1v1_round_atomic()",
    "before_sha256": "cd1daedaf3f721e37c42a403872ea4d6967aa02c95d3d6d079955f1e43090c31",
    "after_sha256": "fb21a6858183813d5fe99c9474e81df6ec29f2b09be2a7c541576c82d2b1878a",
    "begin_offset": 69,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_reset_no_show_count_atomic(uuid)",
    "before_sha256": "50baea0bb3821c5e142ff8019ddfa5f3aa1c00fb0e37778ebad6b0c4b5daf050",
    "after_sha256": "c2f64fc609731e3db92c884242f8450ee77ad8a24bab8f25b5b1b87542de17c2",
    "begin_offset": 69,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_save_1v1_tournament_players_atomic(uuid,jsonb)",
    "before_sha256": "a47d7ecc72a2788462eda982ab82e6b863c7e3852a3eb3c71e5546bcf9786628",
    "after_sha256": "b02bbd0348900a0f11abd6c5f1b66ac6f054a9890a1fa203407099fcc4f168b2",
    "begin_offset": 290,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_set_1v1_registration_open_atomic(boolean)",
    "before_sha256": "7b25e7b7b31bdc7d70170cd43b6fc5a0ebd7e1019333979a16c9162948890232",
    "after_sha256": "31ad7d3c7641e1521f87deb197c741b252b2da899c8c0363d945e3f01f4eb1f5",
    "begin_offset": 72,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_set_maintenance_mode_atomic(boolean)",
    "before_sha256": "26696d8b605d75692f9ed241e8643df8615195e48836affe55740c3a79cf6d36",
    "after_sha256": "6e98f4bff548e5b4c2a3b58d124b289927f640a3dd0466c8d57b4292c9fbc21b",
    "begin_offset": 72,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_set_owner_subscription_atomic(uuid,text,integer)",
    "before_sha256": "78d0a31c9c5143c165b07b11ea9f63aee4519289919c291b3b74df4e80d31756",
    "after_sha256": "3c75af3122e9e6d5f63d7aa12cd773fc6e7733504b129ff6f31757c7fb63141b",
    "begin_offset": 282,
    "origins": [
      "production"
    ]
  },
  {
    "signature": "public.admin_set_owner_subscription_atomic(uuid,text,integer)",
    "before_sha256": "ac4262566f7fc8b4f436518617fa1a7d74c6265ae7e00f910ac23a5a9ed1a77a",
    "after_sha256": "a0a101ccef773b62fd5951b640c4dd5a6d58063d36c22c40d55545c60c627f08",
    "begin_offset": 282,
    "origins": [
      "staging"
    ]
  },
  {
    "signature": "public.admin_settle_owner_cash_debt_atomic(uuid,numeric,text)",
    "before_sha256": "4b07a195ad439629bf409562a1c1ef8a57baaf3468994b473c29ee7b8ac8f63a",
    "after_sha256": "955e04011ff2efaf5c4dee29e294d8ddd569d227522255285857a161af5129b6",
    "begin_offset": 36,
    "origins": [
      "staging"
    ]
  },
  {
    "signature": "public.admin_settle_owner_cash_debt_atomic(uuid,numeric,text)",
    "before_sha256": "c1c4a125685bfdfbde0ced0c41f9fdec9eb4869892a3c5af5a051467def3e11e",
    "after_sha256": "832e8a8d84c7a800f06e23c1471ff28ea508b4dde52b7a0dc3f560d82eb80055",
    "begin_offset": 36,
    "origins": [
      "production"
    ]
  },
  {
    "signature": "public.admin_toggle_user_block(uuid,boolean)",
    "before_sha256": "1c28da02a35a910920b226218127350ae8bd0e8fbefd1a5fd5447f2ba90bca59",
    "after_sha256": "bbe27961f8ab797340f3351ee6b3f2622a1abf0288e31b7c90bc8a2705320138",
    "begin_offset": 79,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_update_1v1_player_stats_atomic(uuid,integer,integer,integer,integer,integer,text)",
    "before_sha256": "936bd95db2ada7068ff985eddb573f1cb50a292f38114f337c9d25c388ebf3f8",
    "after_sha256": "35d508f40bcc37f61cd5e956c9734c02fac4f8796d4324842a7b24b8182340e6",
    "begin_offset": 69,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_update_1v1_tournament_atomic(uuid,text,integer,numeric,timestamp with time zone,text,numeric)",
    "before_sha256": "65f6116db86b9d59b42aa20627a58148a39972ac8d0092b1fef31085815d8d7c",
    "after_sha256": "eca9358bf26dd0dbc742a4562298317c50d6a5681cceb59de3d7f92aba7c2d29",
    "begin_offset": 239,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_update_1v1_tournament_status(uuid,text,uuid)",
    "before_sha256": "97799b43c5b8177f27e71f7605b5321c32c2d6e54a91c2982aaaba8a4d789c2f",
    "after_sha256": "1bfbf8851c4630fd33aae609b894def3f33ca8ad7806e774aa5c73f29d86376f",
    "begin_offset": 300,
    "origins": [
      "production"
    ]
  },
  {
    "signature": "public.admin_update_1v1_tournament_status(uuid,text,uuid)",
    "before_sha256": "be1a5ca03b29764645c2039bd31c09279fa4ad6512447f54dd951bbf8213d793",
    "after_sha256": "72e15228215fdae3b09c3ef6b8f35ba89c9c1021fccecc606eca29f0e823fc91",
    "begin_offset": 300,
    "origins": [
      "staging"
    ]
  },
  {
    "signature": "public.admin_update_1v1_tournament_status_atomic(uuid,text)",
    "before_sha256": "ae0bd29a99a7ef36bfdd07d7f84db95e2a1dc1e31c13ad0cb100f7dc04a313b4",
    "after_sha256": "c4a04f4c17c62bf9fd441f78e513dcdbf462d3827197e4e433e92c0882feaf08",
    "begin_offset": 148,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_update_booking_safe_atomic(uuid,jsonb)",
    "before_sha256": "c9a319784bc42ca0441af32d4f47c0231d58804023f832c91122ca70e62a25e2",
    "after_sha256": "982d8ee220abb31be559e00c45cc531ec5df21c697ea706ad10c22cf1778e0e2",
    "begin_offset": 156,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_update_championship_status_atomic(uuid,text,text)",
    "before_sha256": "97c190debf13dfbf57da10b12e99bbba1fc813f68ddc14bd49bbdb3be9da67ef",
    "after_sha256": "8b1fdae0675ff57400e1393f873246f96a4c13a14aec7dd27f0a18735453ff1d",
    "begin_offset": 208,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_upgrade_owner_subscription_atomic(uuid,text,integer)",
    "before_sha256": "55ac05121b7741862cd40d0810677f4bd048675f9e0be20a064ac9c2dd28ea2b",
    "after_sha256": "5563b495dc1f56718c3e0c3c686fc9443ad41e76fa240331b40c52f2e00c367b",
    "begin_offset": 27,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.admin_wipe_1v1_data_atomic()",
    "before_sha256": "12b149d7a887ce97874d29da7e1c07728d6175241357581f362b57a6220b4773",
    "after_sha256": "403792f085b7d90811ddff464c654764c7f279f921a5ac18b63e997922e5f0cd",
    "begin_offset": 27,
    "origins": [
      "production",
      "staging"
    ]
  },
  {
    "signature": "public.create_owner_on_behalf(text,text,text,text,text)",
    "before_sha256": "177a5995f07f61acd1cfead1528c09967734dca73dbe12b2e4a99c07729412f8",
    "after_sha256": "71d618d390f6de1aa967bdbb96dc35f35c06074630570cd1d63930f2cc8dbb63",
    "begin_offset": 69,
    "origins": [
      "staging"
    ]
  },
  {
    "signature": "public.create_owner_on_behalf(text,text,text,text,text)",
    "before_sha256": "53e12c6c8b834f139038ec2cadef4dea3ff3503355a224038a72dad852e66680",
    "after_sha256": "23aac9200402d3402b56785b2141677baa29af4eebb2b454ba49bfced70c4d45",
    "begin_offset": 69,
    "origins": [
      "production"
    ]
  },
  {
    "signature": "public.create_owner_on_behalf(text,text,text,text,text)",
    "before_sha256": "e4245c7cf8ebc2bd521f8f1271084fe6ab8ae2565704762410c9951d2cde3782",
    "after_sha256": "ab5b2836d0eec7bf347d924a968439a2e42462dcd477973b3c7782bbd6240ca9",
    "begin_offset": 65,
    "origins": [
      "production_lf"
    ]
  }
]$plan$::jsonb;
 v_injection constant text := E'\n  PERFORM public.require_active_admin_actor();\n';
 s text; o oid; b text; n text; d text; h text; v record;
BEGIN
 FOR s IN SELECT DISTINCT p.signature FROM jsonb_to_recordset(v_plan) AS p(signature text) LOOP
  o:=to_regprocedure(s)::oid;
  IF o IS NULL THEN CONTINUE; END IF;
  SELECT prosrc INTO b FROM pg_proc WHERE oid=o;
  h:=encode(sha256(convert_to(b,'UTF8')),'hex');
  IF EXISTS(SELECT 1 FROM jsonb_to_recordset(v_plan) AS p(signature text,before_sha256 text) WHERE p.signature=s AND p.before_sha256=h) THEN CONTINUE; END IF;
  SELECT p.* INTO v FROM jsonb_to_recordset(v_plan) AS p(signature text,before_sha256 text,after_sha256 text,begin_offset integer) WHERE p.signature=s AND p.after_sha256=h LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'ADMIN_RPC_ROLLBACK_SOURCE_DRIFT: %',s; END IF;
  IF substring(b FROM v.begin_offset+1 FOR length(v_injection))<>v_injection THEN RAISE EXCEPTION 'ADMIN_RPC_ROLLBACK_INJECTION_MISMATCH: %',s; END IF;
  n:=substring(b FROM 1 FOR v.begin_offset)||substring(b FROM v.begin_offset+1+length(v_injection));
  IF encode(sha256(convert_to(n,'UTF8')),'hex')<>v.before_sha256 THEN RAISE EXCEPTION 'ADMIN_RPC_ROLLBACK_HASH_MISMATCH: %',s; END IF;
  d:=pg_get_functiondef(o);
  IF length(d)-length(replace(d,b,''))<>length(b) THEN RAISE EXCEPTION 'ADMIN_RPC_ROLLBACK_AMBIGUOUS_DEFINITION: %',s; END IF;
  EXECUTE replace(d,b,n);
 END LOOP;
END;
$inverse$;

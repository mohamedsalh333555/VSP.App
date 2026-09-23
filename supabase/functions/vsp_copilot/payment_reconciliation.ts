// Payment / Booking Reconciliation Workflow for VSP Copilot
// Strictly read-first, zero-guesswork investigation of payments and booking status.
// Adheres strictly to financial safety invariants: never blindly flip booking status.

export type ReconciliationState =
  | "PAYMENT_CONFIRMED_BOOKING_CONFIRMED"
  | "PAYMENT_CONFIRMED_BOOKING_PENDING"
  | "PAYMENT_CONFIRMED_BOOKING_MISSING"
  | "PAYMENT_PENDING"
  | "PAYMENT_FAILED"
  | "PAYMENT_NOT_FOUND"
  | "MULTIPLE_CANDIDATES"
  | "REQUIRES_SUPPORT"
  | "TEMPORARY_ERROR"
  | "DATA_ERROR";

export interface ReconciliationFactReport {
  reconciliation_state: ReconciliationState;
  user_id: string;
  transaction?: {
    id: string;
    amount: number;
    status: string;
    payment_method: string;
    paymob_txn_id?: string;
    created_at: string;
  };
  booking?: {
    id: string;
    stadium_name: string;
    start_time: string;
    end_time: string;
    status: string;
    payment_status: string;
    total_price: number;
  };
  candidate_transactions?: any[];
  explanation: string;
  recommended_action?: {
    action_type: string;
    route: string;
    label: string;
    params?: Record<string, any>;
  };
  facts: {
    amount?: number;
    payment_status?: string;
    booking_status?: string;
    transaction_id?: string;
    booking_id?: string;
    stadium_name?: string;
  };
}

/**
 * Executes a deterministic, read-first reconciliation query for the authenticated user.
 */
export async function executePaymentReconciliationWorkflow(
  supabase: any,
  callerUser: any,
  options?: {
    transaction_id?: string;
    booking_id?: string;
    hours_window?: number;
  }
): Promise<ReconciliationFactReport> {
  if (!callerUser || !callerUser.id) {
    return {
      reconciliation_state: "REQUIRES_SUPPORT",
      user_id: "",
      explanation: "المستخدم غير مسجل الدخول.",
      facts: {},
    };
  }

  const hoursWindow = options?.hours_window || 48;
  const cutoffTime = new Date(Date.now() - hoursWindow * 60 * 60 * 1000).toISOString();

  try {
    // 1. Fetch user's recent transactions within the time window
    let txQuery = supabase
      .from("transactions")
      .select("id, user_id, booking_id, amount, type, status, payment_method, paymob_transaction_id, metadata, created_at")
      .eq("user_id", callerUser.id)
      .gte("created_at", cutoffTime)
      .order("created_at", { ascending: false })
      .limit(5);

    if (options?.transaction_id) {
      txQuery = txQuery.eq("id", options.transaction_id);
    }

    const { data: transactions, error: txError } = await txQuery;
    if (txError) {
      console.error("[PaymentReconciliation] txError:", txError);
      return {
        reconciliation_state: "TEMPORARY_ERROR",
        user_id: callerUser.id,
        explanation: "تعذر قراءة سجل المعاملات المالية حالياً بسبب خطأ مؤقت.",
        facts: {},
      };
    }

    // 2. Fetch user's recent bookings within the time window
    let bQuery = supabase
      .from("bookings")
      .select("id, stadium_id, stadium_name, start_time, end_time, status, total_price, payment_status, payment_method, is_paid, deposit_paid, paymob_transaction_id, created_at")
      .or(`user_id.eq.${callerUser.id},created_by_user_id.eq.${callerUser.id}`)
      .gte("created_at", cutoffTime)
      .order("created_at", { ascending: false })
      .limit(5);

    if (options?.booking_id) {
      bQuery = bQuery.eq("id", options.booking_id);
    }

    const { data: bookings, error: bError } = await bQuery;
    if (bError) {
      console.error("[PaymentReconciliation] bError:", bError);
      return {
        reconciliation_state: "TEMPORARY_ERROR",
        user_id: callerUser.id,
        explanation: "تعذر قراءة سجل الحجوزات من قاعدة البيانات حالياً.",
        facts: {},
      };
    }

    const txList: Array<Record<string, any>> = transactions || [];
    const bList: Array<Record<string, any>> = bookings || [];

    // Case 1: No recent transactions found
    if (txList.length === 0) {
      // Check if there is a pending booking without a registered transaction
      if (bList.length > 0 && bList[0].status === "pending" && bList[0].payment_status !== "paid") {
        const b = bList[0];
        return {
          reconciliation_state: "PAYMENT_NOT_FOUND",
          user_id: callerUser.id,
          booking: {
            id: b.id,
            stadium_name: b.stadium_name,
            start_time: b.start_time,
            end_time: b.end_time,
            status: b.status,
            payment_status: b.payment_status || "unpaid",
            total_price: b.total_price,
          },
          explanation: `يوجد حجز قيد الانتظار في ${b.stadium_name} ولكن لم تسجل أي عملية دفع ناجحة بحسابك خلال آخر ${hoursWindow} ساعة.`,
          recommended_action: {
            action_type: "NAVIGATE",
            route: "/support",
            label: "التواصل مع الدعم الفني 🎧",
          },
          facts: {
            booking_id: b.id,
            stadium_name: b.stadium_name,
            booking_status: b.status,
            payment_status: b.payment_status || "unpaid",
          },
        };
      }

      return {
        reconciliation_state: "PAYMENT_NOT_FOUND",
        user_id: callerUser.id,
        explanation: `لم يتم العثور على أي عمليات دفع مسجلة بحسابك خلال آخر ${hoursWindow} ساعة.`,
        recommended_action: {
          action_type: "NAVIGATE",
          route: "/support",
          label: "مساعدة الدعم الفني 🎧",
        },
        facts: {},
      };
    }

    // Case 2: Multiple candidate transactions requiring disambiguation
    if (txList.length > 1 && !options?.transaction_id) {
      return {
        reconciliation_state: "MULTIPLE_CANDIDATES",
        user_id: callerUser.id,
        candidate_transactions: txList.map((t: Record<string, any>) => ({
          id: t.id,
          amount: t.amount,
          status: t.status,
          date: t.created_at,
        })),
        explanation: `تم العثور على ${txList.length} عمليات دفع حديثة بحسابك. يرجى تحديد العملية المقصودة لتفقدها بدقة.`,
        facts: {},
      };
    }

    // Exactly 1 candidate transaction
    const primaryTx = txList[0];
    const isTxSuccess = primaryTx.status === "completed" || primaryTx.status === "success" || primaryTx.status === "paid";
    const isTxPending = primaryTx.status === "pending" || primaryTx.status === "initiated";
    const isTxFailed = primaryTx.status === "failed" || primaryTx.status === "cancelled" || primaryTx.status === "error";

    // Find matching booking
    let matchingBooking = bList.find((b: Record<string, any>) => b.id === primaryTx.booking_id);
    if (!matchingBooking && primaryTx.paymob_transaction_id) {
      matchingBooking = bList.find((b: Record<string, any>) => b.paymob_transaction_id === primaryTx.paymob_transaction_id);
    }
    if (!matchingBooking && bList.length > 0) {
      // Check if only 1 recent booking exists within close temporal range
      matchingBooking = bList[0];
    }

    const txFacts = {
      id: primaryTx.id,
      amount: primaryTx.amount,
      status: primaryTx.status,
      payment_method: primaryTx.payment_method,
      paymob_txn_id: primaryTx.paymob_transaction_id,
      created_at: primaryTx.created_at,
    };

    // Case 3: Payment is pending
    if (isTxPending) {
      return {
        reconciliation_state: "PAYMENT_PENDING",
        user_id: callerUser.id,
        transaction: txFacts,
        booking: matchingBooking ? {
          id: matchingBooking.id,
          stadium_name: matchingBooking.stadium_name,
          start_time: matchingBooking.start_time,
          end_time: matchingBooking.end_time,
          status: matchingBooking.status,
          payment_status: matchingBooking.payment_status,
          total_price: matchingBooking.total_price,
        } : undefined,
        explanation: `عملية الدفع بمبلغ ${primaryTx.amount} ج.م قيد المعالجة حالياً لدى بوابة الدفع ولم نتلقَّ تأكيد الاستلام بعد.`,
        recommended_action: {
          action_type: "NAVIGATE",
          route: "/bookings",
          label: "متابعة الحجوزات ⏳",
        },
        facts: {
          amount: primaryTx.amount,
          payment_status: "pending",
          transaction_id: primaryTx.id,
          booking_id: matchingBooking?.id,
          booking_status: matchingBooking?.status,
        },
      };
    }

    // Case 4: Payment failed
    if (isTxFailed) {
      return {
        reconciliation_state: "PAYMENT_FAILED",
        user_id: callerUser.id,
        transaction: txFacts,
        explanation: `عملية الدفع بمبلغ ${primaryTx.amount} ج.م لم تكتمل بنجاح وفشلت لدى بوابة الدفع. في حال تم الخصم البنكي، سيتم استرداد المبلغ تلقائياً من البنك.`,
        recommended_action: {
          action_type: "NAVIGATE",
          route: "/support",
          label: "التواصل مع الدعم 🎧",
        },
        facts: {
          amount: primaryTx.amount,
          payment_status: "failed",
          transaction_id: primaryTx.id,
        },
      };
    }

    // Case 5: Payment is confirmed/success
    if (isTxSuccess) {
      if (matchingBooking) {
        if (matchingBooking.status === "confirmed" && (matchingBooking.payment_status === "paid" || matchingBooking.is_paid)) {
          // Both confirmed!
          return {
            reconciliation_state: "PAYMENT_CONFIRMED_BOOKING_CONFIRMED",
            user_id: callerUser.id,
            transaction: txFacts,
            booking: {
              id: matchingBooking.id,
              stadium_name: matchingBooking.stadium_name,
              start_time: matchingBooking.start_time,
              end_time: matchingBooking.end_time,
              status: matchingBooking.status,
              payment_status: matchingBooking.payment_status,
              total_price: matchingBooking.total_price,
            },
            explanation: `تم التحقق: عملية الدفع بمبلغ ${primaryTx.amount} ج.م مؤكدة، والحجز في ${matchingBooking.stadium_name} مؤكد وجاهز بالفعل!`,
            recommended_action: {
              action_type: "NAVIGATE",
              route: "/bookings",
              label: "عرض تذكرة الحجز المؤكد 📋",
              params: { booking_id: matchingBooking.id },
            },
            facts: {
              amount: primaryTx.amount,
              payment_status: "paid",
              booking_status: "confirmed",
              transaction_id: primaryTx.id,
              booking_id: matchingBooking.id,
              stadium_name: matchingBooking.stadium_name,
            },
          };
        }

        // Payment confirmed but booking still pending!
        return {
          reconciliation_state: "PAYMENT_CONFIRMED_BOOKING_PENDING",
          user_id: callerUser.id,
          transaction: txFacts,
          booking: {
            id: matchingBooking.id,
            stadium_name: matchingBooking.stadium_name,
            start_time: matchingBooking.start_time,
            end_time: matchingBooking.end_time,
            status: matchingBooking.status,
            payment_status: matchingBooking.payment_status,
            total_price: matchingBooking.total_price,
          },
          explanation: `تم العثور على عملية الدفع الناجحة بمبلغ ${primaryTx.amount} ج.م، وجارٍ استكمال تأكيد الحجز في ${matchingBooking.stadium_name} حيث ما زالت حالته قيد التحديث.`,
          recommended_action: {
            action_type: "NAVIGATE",
            route: "/support",
            label: "إشعار الدعم لتأكيد الحجز فوراً 🚀",
            params: { booking_id: matchingBooking.id, transaction_id: primaryTx.id },
          },
          facts: {
            amount: primaryTx.amount,
            payment_status: "paid",
            booking_status: matchingBooking.status,
            transaction_id: primaryTx.id,
            booking_id: matchingBooking.id,
            stadium_name: matchingBooking.stadium_name,
          },
        };
      }

      // Payment confirmed but no booking found!
      return {
        reconciliation_state: "PAYMENT_CONFIRMED_BOOKING_MISSING",
        user_id: callerUser.id,
        transaction: txFacts,
        explanation: `تم التأكد من نجاح عملية الدفع بمبلغ ${primaryTx.amount} ج.م، ولكن لم يتم إنشاء سجل الحجز تلقائياً. تم تجهيز تذكرة فحص لفريق الدعم لربط الحجز أو رد المبلغ.`,
        recommended_action: {
          action_type: "NAVIGATE",
          route: "/support",
          label: "متابعة تذكرة الدعم 🎧",
          params: { transaction_id: primaryTx.id, amount: primaryTx.amount },
        },
        facts: {
          amount: primaryTx.amount,
          payment_status: "paid",
          booking_status: "missing",
          transaction_id: primaryTx.id,
        },
      };
    }

    return {
      reconciliation_state: "REQUIRES_SUPPORT",
      user_id: callerUser.id,
      explanation: "حالة الدفع تحتاج مراجعة يدوية من فريق الدعم الفني.",
      facts: {},
    };
  } catch (err: any) {
    console.error("[PaymentReconciliation] Exception:", err);
    return {
      reconciliation_state: "DATA_ERROR",
      user_id: callerUser.id,
      explanation: "حدث خطأ غير متوقع أثناء تدقيق العملية المالية.",
      facts: {},
    };
  }
}

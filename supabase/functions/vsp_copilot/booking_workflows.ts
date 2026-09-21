// Booking Management Workflows for VSP Copilot
// Provides deterministic, read-first and atomic RPC operations for user booking lifecycle.
// Enforces ownership validation, RBAC, and prevents hallucinated actions.

import type { VisibleEntity } from "./conversation_state.ts";

export interface BookingWorkflowResult {
  success: boolean;
  action: string;
  data: Record<string, any>;
  visible_entities?: VisibleEntity[];
  error?: string;
  app_action?: {
    action_type: string;
    route: string;
    label: string;
    params?: Record<string, any>;
  };
}

/**
 * Workflow A: VIEW USER BOOKINGS
 * Fetches authenticated user's current and past bookings.
 */
export async function executeViewUserBookingsWorkflow(
  supabase: any,
  callerUser: any,
  limit = 10
): Promise<BookingWorkflowResult> {
  if (!callerUser || !callerUser.id) {
    return {
      success: false,
      action: "view_user_bookings",
      data: {},
      error: "المستخدم غير مسجل الدخول.",
    };
  }

  try {
    const { data: bookings, error: dbError } = await supabase
      .from("bookings")
      .select("id, stadium_id, stadium_name, start_time, end_time, status, total_price, payment_status, payment_method, created_at")
      .or(`user_id.eq.${callerUser.id},created_by_user_id.eq.${callerUser.id}`)
      .order("start_time", { ascending: false })
      .limit(limit);

    if (dbError) {
      console.error("[BookingWorkflow] dbError in view_user_bookings:", dbError);
      return {
        success: false,
        action: "view_user_bookings",
        data: {},
        error: "تعذر استرجاع الحجوزات من قاعدة البيانات حالياً.",
      };
    }

    const bookingList = bookings || [];
    const visibleEntities: VisibleEntity[] = bookingList.map((b: any, idx: number) => ({
      reference_key: `booking_${idx + 1}`,
      entity_type: "booking",
      id: b.id,
      name: b.stadium_name || "حجز ملعب",
      booking_id: b.id,
      stadium_name: b.stadium_name,
      start_time: b.start_time,
      end_time: b.end_time,
      status: b.status,
      payment_status: b.payment_status,
      price: b.total_price,
    }));

    return {
      success: true,
      action: "view_user_bookings",
      data: {
        count: bookingList.length,
        bookings: bookingList,
      },
      visible_entities: visibleEntities,
      app_action: {
        action_type: "NAVIGATE",
        route: "/bookings",
        label: "عرض قائمة حجوزاتي 📋",
      },
    };
  } catch (err: any) {
    console.error("[BookingWorkflow] Exception in view_user_bookings:", err);
    return {
      success: false,
      action: "view_user_bookings",
      data: {},
      error: "حدث خطأ غير متوقع أثناء استرجاع الحجوزات.",
    };
  }
}

/**
 * Workflow B: VIEW UPCOMING BOOKING
 * Filters the closest upcoming confirmed/pending booking for the user.
 */
export async function executeViewUpcomingBookingWorkflow(
  supabase: any,
  callerUser: any
): Promise<BookingWorkflowResult> {
  if (!callerUser || !callerUser.id) {
    return {
      success: false,
      action: "view_upcoming_booking",
      data: {},
      error: "المستخدم غير مسجل الدخول.",
    };
  }

  try {
    const nowUtc = new Date().toISOString();
    const { data: upcomingList, error: dbError } = await supabase
      .from("bookings")
      .select("id, stadium_id, stadium_name, start_time, end_time, status, total_price, payment_status, payment_method")
      .or(`user_id.eq.${callerUser.id},created_by_user_id.eq.${callerUser.id}`)
      .gte("end_time", nowUtc)
      .in("status", ["confirmed", "pending"])
      .order("start_time", { ascending: true })
      .limit(3);

    if (dbError) {
      console.error("[BookingWorkflow] dbError in view_upcoming_booking:", dbError);
      return {
        success: false,
        action: "view_upcoming_booking",
        data: {},
        error: "تعذر استرجاع الحجز القادم من قاعدة البيانات.",
      };
    }

    const items = upcomingList || [];
    if (items.length === 0) {
      return {
        success: true,
        action: "view_upcoming_booking",
        data: { has_upcoming: false, booking: null },
        app_action: {
          action_type: "NAVIGATE",
          route: "/stadiums",
          label: "تصفح الملاعب المتاحة ⚽",
        },
      };
    }

    const nextBooking = items[0];
    const visibleEntities: VisibleEntity[] = items.map((b: any, idx: number) => ({
      reference_key: `booking_${idx + 1}`,
      entity_type: "booking",
      id: b.id,
      name: b.stadium_name || "الحجز القادم",
      booking_id: b.id,
      stadium_name: b.stadium_name,
      start_time: b.start_time,
      end_time: b.end_time,
      status: b.status,
      payment_status: b.payment_status,
      price: b.total_price,
    }));

    return {
      success: true,
      action: "view_upcoming_booking",
      data: {
        has_upcoming: true,
        booking: nextBooking,
        all_upcoming: items,
      },
      visible_entities: visibleEntities,
      app_action: {
        action_type: "NAVIGATE",
        route: "/bookings",
        label: "تفاصيل الحجز القادم 🕒",
        params: { booking_id: nextBooking.id },
      },
    };
  } catch (err: any) {
    console.error("[BookingWorkflow] Exception in view_upcoming_booking:", err);
    return {
      success: false,
      action: "view_upcoming_booking",
      data: {},
      error: "حدث تعذر مؤقت أثناء فحص الحجز القادم.",
    };
  }
}

/**
 * Workflow C: VIEW BOOKING DETAILS
 * Retrieves trusted details of a specific booking with ownership validation.
 */
export async function executeViewBookingDetailsWorkflow(
  supabase: any,
  callerUser: any,
  bookingId: string
): Promise<BookingWorkflowResult> {
  if (!callerUser || !callerUser.id) {
    return { success: false, action: "view_booking_details", data: {}, error: "المستخدم غير مسجل الدخول." };
  }
  if (!bookingId) {
    return { success: false, action: "view_booking_details", data: {}, error: "معرف الحجز مطلوب." };
  }

  try {
    const { data: booking, error: dbError } = await supabase
      .from("bookings")
      .select("*")
      .eq("id", bookingId)
      .maybeSingle();

    if (dbError || !booking) {
      return { success: false, action: "view_booking_details", data: {}, error: "لم يتم العثور على الحجز المطلوب." };
    }

    // Ownership check: must be user's booking or user is stadium owner
    const isOwner = booking.user_id === callerUser.id || booking.created_by_user_id === callerUser.id || booking.owner_id === callerUser.id;
    if (!isOwner) {
      return { success: false, action: "view_booking_details", data: {}, error: "غير مصرح لك باستعراض تفاصيل هذا الحجز." };
    }

    return {
      success: true,
      action: "view_booking_details",
      data: { booking },
      app_action: {
        action_type: "NAVIGATE",
        route: "/bookings",
        label: "فتح تفاصيل الحجز 📋",
        params: { booking_id: booking.id },
      },
    };
  } catch (err: any) {
    return { success: false, action: "view_booking_details", data: {}, error: "حدث خطأ أثناء جلب تفاصيل الحجز." };
  }
}

/**
 * Workflow D: CANCEL BOOKING
 * Executes existing atomic cancellation RPC with refund calculations and cutoff verification.
 */
export async function executeCancelBookingWorkflow(
  supabase: any,
  callerUser: any,
  bookingId: string,
  reason = "طلب اللاعب إلغاء الحجز عبر المساعد الذكي"
): Promise<BookingWorkflowResult> {
  if (!callerUser || !callerUser.id) {
    return { success: false, action: "cancel_booking", data: {}, error: "المستخدم غير مسجل الدخول." };
  }
  if (!bookingId) {
    return { success: false, action: "cancel_booking", data: {}, error: "معرف الحجز مطلوب للإلغاء." };
  }

  try {
    // 1. First verify ownership in a read query
    const { data: b, error: checkErr } = await supabase
      .from("bookings")
      .select("id, user_id, created_by_user_id, status, stadium_name, start_time")
      .eq("id", bookingId)
      .maybeSingle();

    if (checkErr || !b) {
      return { success: false, action: "cancel_booking", data: {}, error: "الحجز غير موجود." };
    }

    if (b.user_id !== callerUser.id && b.created_by_user_id !== callerUser.id) {
      return { success: false, action: "cancel_booking", data: {}, error: "غير مصرح لك بإلغاء حجز ليس ملكك." };
    }

    if (b.status === "cancelled") {
      return {
        success: true,
        action: "cancel_booking",
        data: { already_cancelled: true, booking_id: bookingId },
        error: "هذا الحجز ملغى بالفعل.",
      };
    }

    // 2. Call existing atomic RPC
    const { data: rpcRes, error: rpcErr } = await supabase.rpc("cancel_booking_with_refund_atomic", {
      p_booking_id: bookingId,
      p_user_id: callerUser.id,
      p_reason: reason,
    });

    if (rpcErr) {
      console.error("[BookingWorkflow] RPC error cancel_booking_with_refund_atomic:", rpcErr);
      return {
        success: false,
        action: "cancel_booking",
        data: {},
        error: rpcErr.message || "تعذر إلغاء الحجز عبر النظام الذري حالياً.",
      };
    }

    if (rpcRes && rpcRes.success === false) {
      return {
        success: false,
        action: "cancel_booking",
        data: rpcRes,
        error: rpcRes.message || "تعذر إلغاء الحجز وفقاً للائحة الإلغاء.",
      };
    }

    return {
      success: true,
      action: "cancel_booking",
      data: {
        booking_id: bookingId,
        stadium_name: b.stadium_name,
        refund_amount: rpcRes?.refund_amount || 0,
        transaction_id: rpcRes?.transaction_id,
      },
      app_action: {
        action_type: "NAVIGATE",
        route: "/bookings",
        label: "عرض سجل الحجوزات 📋",
      },
    };
  } catch (err: any) {
    console.error("[BookingWorkflow] Exception in cancel_booking:", err);
    return {
      success: false,
      action: "cancel_booking",
      data: {},
      error: "حدث تعذر مؤقت أثناء تنفيذ إلغاء الحجز.",
    };
  }
}

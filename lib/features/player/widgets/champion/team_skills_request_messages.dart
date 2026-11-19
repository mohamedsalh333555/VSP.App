/// Deliberately separate from success/failure of transport: ambiguous writes
/// must never claim that a registration or withdrawal did not happen.
enum TeamSkillsRequestNotice {
  rosterUnavailable,
  registrationClosed,
  registrationUnconfirmed,
  waitlisted,
  approved,
  pending,
  alreadyWaitlisted,
  alreadyPending,
  registrationCheckUnavailable,
  rosterSavedApproved,
  rosterSavedWaitlist,
  rosterSavedPending,
  rosterSavedUnconfirmed,
  rosterSavedRefreshFailed,
  withdrawn,
  withdrawalUnconfirmed,
  alreadyWithdrawn,
  withdrawalRetryUnconfirmed,
  withdrawalCheckUnavailable,
}

class TeamSkillsRequestMessages {
  const TeamSkillsRequestMessages._();

  static String localize(
    TeamSkillsRequestNotice notice, {
    required bool isArabic,
  }) {
    switch (notice) {
      case TeamSkillsRequestNotice.rosterUnavailable:
        return isArabic
            ? 'تعذر التحقق من أعضاء الفريق. أعد المحاولة.'
            : 'Could not verify team members. Please retry.';
      case TeamSkillsRequestNotice.registrationClosed:
        return isArabic
            ? 'التسجيل لم يعد مفتوحًا لهذه البطولة.'
            : 'Registration is no longer open for this cup.';
      case TeamSkillsRequestNotice.registrationUnconfirmed:
        return isArabic
            ? 'تم إرسال الطلب لكن تعذر تأكيد تسجيل الفريق. راجع حالة طلبك قبل المحاولة مجددًا.'
            : 'Your registration request was sent, but its status could not be confirmed. Check the request before trying again.';
      case TeamSkillsRequestNotice.waitlisted:
        return isArabic
            ? 'تم تسجيل فريقك في قائمة الانتظار. ستراجع الإدارة طلبك عند توفر مكان.'
            : 'Your team is on the waiting list. Organizers will review the request if a spot becomes available.';
      case TeamSkillsRequestNotice.approved:
        return isArabic
            ? 'تم اعتماد مشاركة فريقك بالفعل.'
            : 'Your team has already been approved.';
      case TeamSkillsRequestNotice.pending:
        return isArabic
            ? 'تم إرسال طلب تسجيل الفريق. في انتظار موافقة إدارة البطولة.'
            : 'The team registration request was sent and is awaiting organizer approval.';
      case TeamSkillsRequestNotice.alreadyWaitlisted:
        return isArabic
            ? 'طلب فريقك مسجل بالفعل على قائمة الانتظار.'
            : 'Your team already has a waitlist request.';
      case TeamSkillsRequestNotice.alreadyPending:
        return isArabic
            ? 'طلب فريقك مسجل بالفعل وينتظر مراجعة الإدارة.'
            : 'Your team already has a registration request awaiting review.';
      case TeamSkillsRequestNotice.registrationCheckUnavailable:
        return isArabic
            ? 'تعذر التحقق من حالة التسجيل. راجع حالة الفريق قبل إعادة المحاولة.'
            : 'Could not confirm registration status. Check your team request before retrying.';
      case TeamSkillsRequestNotice.rosterSavedApproved:
        return isArabic
            ? 'تم حفظ التشكيلة، وقد اعتمدت الإدارة مشاركة فريقك.'
            : 'Roster saved. Organizers have approved your team.';
      case TeamSkillsRequestNotice.rosterSavedWaitlist:
        return isArabic
            ? 'تم حفظ التشكيلة، والفريق ما زال في قائمة الانتظار.'
            : 'Roster saved. Your team is still waitlisted.';
      case TeamSkillsRequestNotice.rosterSavedPending:
        return isArabic
            ? 'تم حفظ التشكيلة، والطلب ما زال ينتظر مراجعة الإدارة.'
            : 'Roster saved. The request is still awaiting organizer approval.';
      case TeamSkillsRequestNotice.rosterSavedUnconfirmed:
        return isArabic
            ? 'تم حفظ التشكيلة، لكن تعذر تأكيد حالة المشاركة الحالية.'
            : 'Roster saved, but the current participation status could not be confirmed.';
      case TeamSkillsRequestNotice.rosterSavedRefreshFailed:
        return isArabic
            ? 'تم حفظ التشكيلة، لكن تعذر تحديث حالة الطلب. أعد التحميل.'
            : 'Roster saved, but the request status could not be refreshed. Reload to check.';
      case TeamSkillsRequestNotice.withdrawn:
        return isArabic
            ? 'تم سحب طلب الفريق وتحرير مكانه.'
            : 'The team request was withdrawn and its spot released.';
      case TeamSkillsRequestNotice.withdrawalUnconfirmed:
        return isArabic
            ? 'تم إرسال طلب السحب لكن تعذر تأكيد حالته. راجع طلبك قبل المحاولة مجددًا.'
            : 'Withdrawal was submitted, but its status could not be confirmed. Check your request before trying again.';
      case TeamSkillsRequestNotice.alreadyWithdrawn:
        return isArabic
            ? 'طلب الفريق مسحوب بالفعل، وتم تحرير مكانه.'
            : 'The request was already withdrawn and its spot released.';
      case TeamSkillsRequestNotice.withdrawalRetryUnconfirmed:
        return isArabic
            ? 'تعذر تأكيد السحب. تحقق من حالة طلبك قبل المحاولة مجددًا.'
            : 'Could not confirm withdrawal. Check your request status before retrying.';
      case TeamSkillsRequestNotice.withdrawalCheckUnavailable:
        return isArabic
            ? 'تعذر التحقق من طلب السحب. راجع حالة الفريق قبل المحاولة مجددًا.'
            : 'Could not check withdrawal status. Review the team\'s request before retrying.';
    }
  }
}

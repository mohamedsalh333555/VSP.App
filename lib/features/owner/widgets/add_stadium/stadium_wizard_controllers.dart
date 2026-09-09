import 'package:flutter/material.dart';
import 'stadium_wizard_data_loader.dart';
import 'stadium_wizard_draft_service.dart';

/// Encapsulates all form text editing controllers, their auto-save bindings, and batch population logic.
class StadiumWizardControllers {
  final name = TextEditingController();
  final price = TextEditingController();
  final capacity = TextEditingController();
  final location = TextEditingController();
  final length = TextEditingController();
  final width = TextEditingController();
  final seats = TextEditingController();
  final notes = TextEditingController();
  final phone = TextEditingController();
  final ballPrice = TextEditingController();
  final deposit = TextEditingController();

  /// Attaches auto-save listeners to save input changes to persistent local draft.
  void setupAutoSave(String? uid) {
    name.addListener(() => StadiumWizardDraftService.saveString(uid, 'name', name.text));
    location.addListener(() => StadiumWizardDraftService.saveString(uid, 'location', location.text));
    price.addListener(() => StadiumWizardDraftService.saveString(uid, 'price', price.text));
    capacity.addListener(() => StadiumWizardDraftService.saveString(uid, 'capacity', capacity.text));
    phone.addListener(() => StadiumWizardDraftService.saveString(uid, 'phone', phone.text));
    notes.addListener(() => StadiumWizardDraftService.saveString(uid, 'notes', notes.text));
    length.addListener(() => StadiumWizardDraftService.saveString(uid, 'length', length.text));
    width.addListener(() => StadiumWizardDraftService.saveString(uid, 'width', width.text));
    seats.addListener(() => StadiumWizardDraftService.saveString(uid, 'seats', seats.text));
    ballPrice.addListener(() => StadiumWizardDraftService.saveString(uid, 'ball_price', ballPrice.text));
    deposit.addListener(() => StadiumWizardDraftService.saveString(uid, 'deposit', deposit.text));
  }

  /// Populates all text controllers from restored draft data.
  void populateFromDraft(StadiumDraftData draft) {
    name.text = draft.name;
    location.text = draft.location;
    price.text = draft.price;
    capacity.text = draft.capacity;
    phone.text = draft.phone;
    notes.text = draft.notes;
    length.text = draft.length;
    width.text = draft.width;
    seats.text = draft.seats;
    ballPrice.text = draft.ballPrice;
    deposit.text = draft.deposit;
  }

  /// Populates all text controllers from loaded database record in edit mode.
  void populateFromLoaded(StadiumLoadedData loaded) {
    name.text = loaded.name;
    location.text = loaded.location;
    price.text = loaded.price;
    capacity.text = loaded.capacity;
    deposit.text = loaded.deposit;
    phone.text = loaded.phone;
    seats.text = loaded.seats;
    length.text = loaded.length;
    width.text = loaded.width;
    ballPrice.text = loaded.ballPrice;
    notes.text = loaded.notes;
  }

  /// Disposes all text editing controllers safely.
  void dispose() {
    name.dispose();
    price.dispose();
    capacity.dispose();
    location.dispose();
    length.dispose();
    width.dispose();
    seats.dispose();
    notes.dispose();
    phone.dispose();
    ballPrice.dispose();
    deposit.dispose();
  }
}

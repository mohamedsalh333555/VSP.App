# VSP — booking ball-rental UI state guard

Branch-only, no backend price changes. In \`BookingBottomBar\`, optional ball rental can only be toggled after an active time slot is selected. A previously opted-in add-on should not remain visually selected if the user clears the selected date or slot. The bar now masks a stale \`isBallRented\` flag and hides a stale total (shows zero) until a valid slot is selected.

Widget tests simulate a stale selected-ball flag with no slot, and verify a valid time slot allows ball-rental toggle and displays the recalculated parent-supplied total. They do not independently certify backend prices, deposit calculations or signed customer settlement. Task 83.07 remains open until parent state calculation and server price reconciliation are verified. No financial mutation or deployment occurred.

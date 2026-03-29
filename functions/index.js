const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

/**
 * [COO] Automated Debt Calculation
 * Triggers when a booking status changes to 'completed'.
 * Calculates 5% commission and updates owner's debt.
 * If debt exceeds 500, blocks all owner's stadiums.
 */
exports.onBookingStatusChanged = functions.firestore
    .document("bookings/{bookingId}")
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const oldData = change.before.data();

        // Only act if status changed to 'completed'
        if (oldData.status !== "completed" && newData.status === "completed") {
            const ownerId = newData.ownerId;
            const totalPrice = newData.totalPrice || 0;
            const commission = totalPrice * 0.05;

            const ownerRef = db.collection("users").doc(ownerId);
            
            return db.runTransaction(async (transaction) => {
                const ownerDoc = await transaction.get(ownerRef);
                if (!ownerDoc.exists) return;

                const currentDebt = (ownerDoc.data().commissionDebt || 0) + commission;
                const shouldBlock = currentDebt >= 500;

                transaction.update(ownerRef, {
                    commissionDebt: currentDebt,
                    isSuspended: shouldBlock
                });

                // If threshold reached, block all stadiums
                if (shouldBlock) {
                    const stadiumsQuery = await db.collection("stadiums")
                        .where("ownerId", "==", ownerId)
                        .get();
                    
                    stadiumsQuery.forEach(doc => {
                        transaction.update(doc.ref, { isBlocked: true });
                    });
                }
            });
        }
        return null;
    });

/**
 * [CTO] Secure Tournament Winner Processing
 * Callable function to prevent client-side manipulation.
 * Handles bracket progression and trophy assignment.
 */
exports.processTournamentWinner = functions.https.onCall(async (data, context) => {
    // Auth check
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Auth required.");
    }

    const { matchId, winningTeamId, winningTeamName } = data;

    const matchRef = db.collection("tournament_matches").doc(matchId);
    
    return db.runTransaction(async (transaction) => {
        const matchDoc = await transaction.get(matchRef);
        if (!matchDoc.exists) throw new Error("Match not found");

        const matchData = matchDoc.data();
        const nextMatchId = matchData.nextMatchId;

        // 1. Update Current Match
        transaction.update(matchRef, {
            winnerId: winningTeamId,
            status: "completed"
        });

        // 2. Propagate to Next Match or Crown Champion
        if (nextMatchId) {
            const nextMatchRef = db.collection("tournament_matches").doc(nextMatchId);
            const slotField = (matchData.matchIndex % 2 === 0) ? "home" : "away";

            transaction.update(nextMatchRef, {
                [`${slotField}TeamId`]: winningTeamId,
                [`${slotField}TeamName`]: winningTeamName
            });
        } else {
            // It was the Final!
            const champRef = db.collection("championships").doc(matchData.championshipId);
            transaction.update(champRef, {
                status: "completed",
                championTeamId: winningTeamId,
                championTeamName: winningTeamName
            });

            // Update Team Record
            const teamRef = db.collection("teams").doc(winningTeamId);
            transaction.update(teamRef, {
                championshipsWon: admin.firestore.FieldValue.increment(1),
                unlockedBadges: admin.firestore.FieldValue.arrayUnion("cup_winner")
            });
        }
        return { success: true };
    });
});

/**
 * [FINANCE] Hourly Automated Reconciliation
 * Runs every hour to complete past bookings and calculate commission debt.
 * This prevents owners from avoiding debt by never opening the app.
 */
exports.hourlyReconciliation = functions.pubsub
    .schedule("every 1 hours")
    .onRun(async (context) => {
        const now = admin.firestore.Timestamp.now();
        
        // 1. Get all bookings that ended in the past and are not yet reconciled (not 'completed' or 'cancelled')
        const bookingsQuery = await db.collection("bookings")
            .where("endTime", "<", now)
            .where("isPaid", "==", false)
            .where("status", "==", "confirmed")
            .get();

        if (bookingsQuery.empty) {
            console.log("No pending reconciliations found.");
            return null;
        }

        const batch = db.batch();
        const ownerDebtMap = new Map();

        // 2. Process each booking
        bookingsQuery.forEach(doc => {
            const data = doc.data();
            const commission = (data.totalPrice || 0) * 0.05;
            const ownerId = data.ownerId;

            // Update booking status
            batch.update(doc.ref, { 
                status: "completed",
                isPaid: true, // Mark as processed for reconciliation
                reconciledAt: admin.firestore.FieldValue.serverTimestamp()
            });

            // Accumulate debt per owner to process once
            const currentOwnerDebt = ownerDebtMap.get(ownerId) || 0;
            ownerDebtMap.set(ownerId, currentOwnerDebt + commission);
        });

        // 3. Update Owners Debt & Status
        for (const [ownerId, totalNewCommission] of ownerDebtMap.entries()) {
            const ownerRef = db.collection("users").doc(ownerId);
            const ownerDoc = await ownerRef.get();
            
            if (ownerDoc.exists) {
                const currentDebt = (ownerDoc.data().commissionDebt || 0) + totalNewCommission;
                const isSuspended = currentDebt >= 500;
                
                batch.update(ownerRef, {
                    commissionDebt: currentDebt,
                    isSuspended: isSuspended,
                    lastReconciliation: admin.firestore.FieldValue.serverTimestamp()
                });
            }
        }

        await batch.commit();
        console.log(`Successfully reconciled ${bookingsQuery.size} bookings.`);
        return null;
    });

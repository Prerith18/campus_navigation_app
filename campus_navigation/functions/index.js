/* functions/index.js (v1 style, 2nd-gen compatible) */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.onAdminNotificationCreated = functions
  .region("europe-west2")
  .firestore.document("admin_notifications/{id}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const title = data.title || "";
    const body = data.body || "";
    const image = data.image || null;
    const deeplink = data.deeplink || null;

    const db = admin.firestore();
    const ts = admin.firestore.FieldValue.serverTimestamp();
    const notifId = context.params.id;

    // 1) Global feed (optional, read-only for clients)
    await db.collection("notifications").doc(notifId).set(
      {title, body, image, deeplink, createdAt: ts},
      {merge: true},
    );

    // 2) Fan-out to every user’s inbox (what the Home bell reads)
    const users = await db.collection("users").select().get(); // fetch only ids
    const commits = [];
    let batch = db.batch();
    let writes = 0;

    users.forEach((u) => {
      const ref = db.collection("userNotifications")
        .doc(u.id)
        .collection("items")
        .doc(notifId);

      batch.set(
        ref,
        {title, body, image, deeplink, createdAt: ts, read: false},
        {merge: true},
      );

      writes++;
      if (writes >= 400) { // keep well under Firestore 500/writes-per-batch
        commits.push(batch.commit());
        batch = db.batch();
        writes = 0;
      }
    });
    if (writes > 0) commits.push(batch.commit());
    await Promise.all(commits);

    // 3) Push a system notification to everyone subscribed to topic "all"
    try {
      await admin.messaging().send({
        topic: "all",
        notification: {title, body},
        data: {deeplink: deeplink || ""},
        android: image ? {notification: {imageUrl: image}} : undefined,
        apns: image ? {fcm_options: {image}} : undefined,
      });
    } catch (e) {
      console.error("FCM send failed:", e);
    }
  });

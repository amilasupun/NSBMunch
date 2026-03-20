// functions/index.js
// Firebase Cloud Functions v4+ syntax

const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// ── HELPER: Send FCM + save notification ─────────────────
async function sendToUser(userId, title, body) {
  await db.collection("notifications").add({
    userId: userId,
    title: title,
    body: body,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  const userDoc = await db.collection("users").doc(userId).get();
  const token = userDoc.data()?.fcmToken;
  if (!token) return;

  try {
    await messaging.send({
      token: token,
      notification: { title: title, body: body },
      android: {
        notification: {
          channelId: "nsbmunch_channel",
          priority: "high",
          sound: "default",
        },
      },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
    });
  } catch (e) {
    console.log("FCM error for user", userId, ":", e.message);
    if (e.code === "messaging/registration-token-not-registered") {
      await db.collection("users").doc(userId).update({ fcmToken: null });
    }
  }
}

// ── HELPER: Send to shop owner ───────────────────────────
async function sendToShop(shopId, title, body) {
  const snap = await db
    .collection("users")
    .where("shopId", "==", shopId)
    .where("role", "==", "vendor")
    .get();
  for (const doc of snap.docs) {
    await sendToUser(doc.id, title, body);
  }
}

// ── TRIGGER 1: New order → notify vendor ─────────────────
exports.onOrderCreated = onDocumentCreated(
  "orders/{orderId}",
  async (event) => {
    const order = event.data?.data();
    if (!order) return;
    const orderNumber = order.orderNumber || event.params.orderId;
    await sendToShop(
      order.shopId,
      "New Order Request",
      `Order ${orderNumber} received. Rs. ${order.totalPrice}.`
    );
  }
);

// ── TRIGGER 2: Order updated → notify user ───────────────
// FIX #8: Only send ONE notification per update — check what changed and pick priority
exports.onOrderUpdated = onDocumentUpdated(
  "orders/{orderId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const userId = after.userId;
    const orderNumber = after.orderNumber || event.params.orderId;

    // FIX #8: If BOTH status and paymentStatus changed at the same time (confirm order),
    // only send the payment notification — it's more important to the user.
    const statusChanged = before.status !== after.status;
    const paymentChanged = before.paymentStatus !== after.paymentStatus;

    // Payment confirmed — highest priority, send this only
    if (paymentChanged && after.paymentStatus === "confirmed") {
      await sendToUser(
        userId,
        "Order Confirmed - Payment Successful",
        `Order ${orderNumber} confirmed. Payment successful!`
      );
      return; // FIX #8: return early — don't send status notification too
    }

    // Order status changed — only if payment didn't also change
    if (statusChanged) {
      // FIX #7: Use "completed" consistently (matches order_model.dart)
      if (after.status === "ready") {
        await sendToUser(
          userId,
          "Order Ready for Pickup",
          `Order ${orderNumber} is ready. Please collect your food.`
        );
      } else if (after.status === "completed") {
        await sendToUser(
          userId,
          "Order Collected",
          `Order ${orderNumber} picked up. Enjoy your meal!`
        );
      } else if (after.status === "cancelled") {
        await sendToUser(
          userId,
          "Order Cancelled",
          `Order ${orderNumber} was cancelled. Payment declined.`
        );
      }
    }
  }
);

// ── TRIGGER 3: Scheduled orders — every minute ───────────
// FIX #2: Use Asia/Colombo timezone for Sri Lanka (UTC+5:30)
exports.checkScheduledOrders = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Asia/Colombo", // FIX #2: Sri Lanka timezone
  },
  async (event) => {
    const now = new Date();

    // FIX #2: Get current time in Sri Lanka timezone
    const sriLankaTime = new Date(
      now.toLocaleString("en-US", { timeZone: "Asia/Colombo" })
    );

    const dd = String(sriLankaTime.getDate()).padStart(2, "0");
    const mm = String(sriLankaTime.getMonth() + 1).padStart(2, "0");
    const yyyy = sriLankaTime.getFullYear();
    const todayStr = `${dd}/${mm}/${yyyy}`;

    const nowTotalMinutes =
      sriLankaTime.getHours() * 60 + sriLankaTime.getMinutes();

    console.log(
      `Checking scheduled orders at ${sriLankaTime.toISOString()} (LK), today=${todayStr}, nowMinutes=${nowTotalMinutes}`
    );

    const snap = await db
      .collection("scheduled_orders")
      .where("triggered", "==", false)
      .where("paymentStatus", "==", "payment_pending")
      .get();

    console.log(`Found ${snap.docs.length} pending scheduled orders`);

    for (const doc of snap.docs) {
      const order = doc.data();
      const pickupDate = order.pickupDate;
      const paymentTime = order.paymentTime;

      if (!pickupDate || !paymentTime) {
        console.log(`Skipping ${doc.id}: missing date or time`);
        continue;
      }

      if (pickupDate !== todayStr) {
        console.log(
          `Skipping ${doc.id}: pickupDate=${pickupDate} != today=${todayStr}`
        );
        continue;
      }

      const timeParts = paymentTime.split(":");
      if (timeParts.length < 2) {
        console.log(
          `Skipping ${doc.id}: invalid paymentTime format: ${paymentTime}`
        );
        continue;
      }

      const payH = parseInt(timeParts[0], 10);
      const payM = parseInt(timeParts[1], 10);
      const payTotalMinutes = payH * 60 + payM;

      console.log(
        `Order ${doc.id}: paymentTime=${paymentTime} (${payTotalMinutes} min), now=${nowTotalMinutes} min`
      );

      if (nowTotalMinutes < payTotalMinutes) {
        console.log(`Not yet time for ${doc.id}`);
        continue;
      }

      const shopId = order.shopId || "";
      const shopPart = shopId.substring(0, 4).toUpperCase();
      const orderNumber = `ORD-${shopPart}-${Date.now()}`;

      console.log(`Triggering scheduled order ${doc.id} → ${orderNumber}`);

      // FIX #7: Use "completed" status consistently — matches order_model.dart
      await db.collection("orders").add({
        userId: order.userId,
        shopId: order.shopId,
        shopName: order.shopName,
        items: order.items,
        totalPrice: order.totalPrice,
        status: "pending",
        paymentStatus: "hold",
        pickupTime: order.pickupTime,
        orderNumber: orderNumber,
        isScheduled: true,
        scheduledOrderId: doc.id,
        createdAt: FieldValue.serverTimestamp(),
      });

      await doc.ref.update({
        triggered: true,
        orderNumber: orderNumber,
        paymentStatus: "hold",
      });

      await sendToUser(
        order.userId,
        "Scheduled Order Sent",
        `Your scheduled order ${orderNumber} has been sent to ${order.shopName}.`
      );

      console.log(`Successfully triggered: ${doc.id} → ${orderNumber}`);
    }
  }
);
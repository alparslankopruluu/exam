import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { onCall } from "firebase-functions/v2/https";
import { requireUid } from "./auth.js";

const db = getFirestore();
const bucket = getStorage().bucket();

async function deleteQuery(path: string, uid: string): Promise<void> {
  while (true) {
    const snapshot = await db.collection(path)
      .where("uid", "==", uid)
      .limit(400)
      .get();

    if (snapshot.empty) return;

    const batch = db.batch();
    snapshot.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();

    if (snapshot.size < 400) return;
  }
}

export const deleteAccount = onCall(
  { timeoutSeconds: 120, memory: "512MiB" },
  async request => {
    const uid = requireUid(request);

    await Promise.allSettled([
      bucket.deleteFiles({ prefix: `users/${uid}/` }),
      deleteQuery("pushTokens", uid),
      deleteQuery("aiJobs", uid),
      deleteQuery("purchaseLedger", uid)
    ]);

    const userRef = db.doc(`users/${uid}`);
    await db.recursiveDelete(userRef);

    await getAuth().deleteUser(uid);

    return { deleted: true };
  }
);

import { initializeApp } from "firebase-admin/app";

initializeApp();

export {
  aiTutor,
  solveQuestion,
  generatePractice,
  indexMaterial,
  askMaterial,
  generateMaterialPractice,
  mediaGenerate,
  mediaStatus,
  transcribeAudio,
  synthesizeSpeech
} from "./ai.js";

export { verifyStorePurchase } from "./purchases.js";

export { registerPushToken, sendStudyReminders } from "./push.js";

export { appleStoreNotifications, googlePlayBillingEvents } from "./storeNotifications.js";

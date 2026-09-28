import { defineSecret, defineString } from "firebase-functions/params";

export const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");
export const FAL_KEY = defineSecret("FAL_KEY");
export const APPLE_IAP_PRIVATE_KEY = defineSecret("APPLE_IAP_PRIVATE_KEY");
export const APPLE_ROOT_CERTS_B64_JSON = defineSecret("APPLE_ROOT_CERTS_B64_JSON");

export const OPENAI_TEXT_MODEL = defineString("OPENAI_TEXT_MODEL", { default: "gpt-5" });
export const OPENAI_EMBED_MODEL = defineString("OPENAI_EMBED_MODEL", { default: "text-embedding-3-small" });
export const OPENAI_TTS_MODEL = defineString("OPENAI_TTS_MODEL", { default: "gpt-4o-mini-tts" });
export const OPENAI_TTS_VOICE = defineString("OPENAI_TTS_VOICE", { default: "coral" });

export const FAL_IMAGE_MODEL = defineString("FAL_IMAGE_MODEL", { default: "fal-ai/flux-2-flex" });
export const FAL_VIDEO_MODEL = defineString("FAL_VIDEO_MODEL", { default: "fal-ai/ovi" });
export const FAL_STT_MODEL = defineString("FAL_STT_MODEL", { default: "fal-ai/speech-to-text" });

export const APPLE_KEY_ID = defineString("APPLE_KEY_ID", { default: "" });
export const APPLE_ISSUER_ID = defineString("APPLE_ISSUER_ID", { default: "" });
export const APPLE_BUNDLE_ID = defineString("APPLE_BUNDLE_ID", { default: "com.kprl.exam" });
export const APPLE_APP_ID = defineString("APPLE_APP_ID", { default: "0" });
export const APPLE_ENVIRONMENT = defineString("APPLE_ENVIRONMENT", { default: "Sandbox" });

export const FREE_AI_CALLS_PER_DAY = defineString("FREE_AI_CALLS_PER_DAY", { default: "5" });

export const REMINDER_IMAGE_URL = defineString("REMINDER_IMAGE_URL", { default: "" });

export const FREE_MATERIALS_LIMIT = defineString("FREE_MATERIALS_LIMIT", { default: "3" });

// Kill switch for server-issued paywall offers.
export const OFFERS_ENABLED = defineString("OFFERS_ENABLED", { default: "true" });

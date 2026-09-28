// Localized reminder copy. Placeholders: {exam}, {streak}, {count}.

export type ReminderKind = "daily" | "streak_at_risk" | "review_due" | "comeback" | "offer_expiring";

type Copy = { title: string; body: string };

export const REMINDER_COPY: Record<ReminderKind, Record<string, Copy>> = {
  daily: {
    en: { title: "Your {exam} plan is ready", body: "A short session today keeps your progress moving." },
    tr: { title: "{exam} planın hazır", body: "Kısa bir çalışma bile ilerlemeni sürdürür." },
    de: { title: "Dein {exam}-Plan ist bereit", body: "Eine kurze Einheit hält deinen Fortschritt auf Kurs." },
    es: { title: "Tu plan de {exam} está listo", body: "Una sesión corta mantiene tu progreso." },
    fr: { title: "Ton plan {exam} est prêt", body: "Une courte session suffit pour continuer à progresser." },
    pt: { title: "Seu plano de {exam} está pronto", body: "Uma sessão curta mantém seu progresso." },
    ko: { title: "오늘의 {exam} 계획이 준비됐어요", body: "짧게라도 공부하면 흐름을 이어갈 수 있어요." },
    ja: { title: "今日の{exam}プランができました", body: "短い学習でも進歩を続けられます。" },
    hi: { title: "आज का {exam} प्लान तैयार है", body: "एक छोटा सत्र भी आपकी प्रगति बनाए रखता है।" }
  },
  streak_at_risk: {
    en: { title: "Keep your {streak}-day streak 🔥", body: "One quick session today and it stays alive." },
    tr: { title: "{streak} günlük serini koru 🔥", body: "Bugün kısa bir çalışma yeter, seri devam etsin." },
    de: { title: "Halte deine {streak}-Tage-Serie 🔥", body: "Eine kurze Einheit heute und sie bleibt bestehen." },
    es: { title: "Mantén tu racha de {streak} días 🔥", body: "Una sesión rápida hoy y sigue viva." },
    fr: { title: "Garde ta série de {streak} jours 🔥", body: "Une petite session aujourd’hui et elle continue." },
    pt: { title: "Mantenha sua sequência de {streak} dias 🔥", body: "Uma sessão rápida hoje e ela continua." },
    ko: { title: "{streak}일 연속 기록을 지켜요 🔥", body: "오늘 짧게 한 번만 공부하면 이어져요." },
    ja: { title: "{streak}日連続記録をキープ 🔥", body: "今日少し学習するだけで続きます。" },
    hi: { title: "अपनी {streak} दिन की स्ट्रीक बचाएँ 🔥", body: "आज एक छोटा सत्र और स्ट्रीक जारी रहेगी।" }
  },
  review_due: {
    en: { title: "{count} topics are ready for review", body: "Reviewing now is the fastest way to lock them in." },
    tr: { title: "{count} konu tekrar zamanında", body: "Şimdi tekrar etmek kalıcı öğrenmenin en hızlı yolu." },
    de: { title: "{count} Themen sind bereit zur Wiederholung", body: "Jetzt wiederholen festigt sie am schnellsten." },
    es: { title: "{count} temas listos para repasar", body: "Repasar ahora es la forma más rápida de fijarlos." },
    fr: { title: "{count} notions à réviser", body: "Réviser maintenant est le moyen le plus rapide de les ancrer." },
    pt: { title: "{count} tópicos prontos para revisão", body: "Revisar agora é o jeito mais rápido de fixar." },
    ko: { title: "복습할 주제 {count}개", body: "지금 복습하면 가장 빠르게 기억에 남아요." },
    ja: { title: "復習のタイミングが{count}件", body: "今復習するのが定着への近道です。" },
    hi: { title: "{count} टॉपिक दोहराने के लिए तैयार", body: "अभी दोहराना इन्हें याद रखने का सबसे तेज़ तरीका है।" }
  },
  comeback: {
    en: { title: "Pick up where you left off", body: "Your {exam} plan adapted while you were away. 10 minutes is enough." },
    tr: { title: "Kaldığın yerden devam et", body: "{exam} planın sen yokken güncellendi. 10 dakika yeterli." },
    de: { title: "Mach da weiter, wo du aufgehört hast", body: "Dein {exam}-Plan hat sich angepasst. 10 Minuten reichen." },
    es: { title: "Retoma donde lo dejaste", body: "Tu plan de {exam} se adaptó. Con 10 minutos basta." },
    fr: { title: "Reprends là où tu t’étais arrêté", body: "Ton plan {exam} s’est adapté. 10 minutes suffisent." },
    pt: { title: "Continue de onde parou", body: "Seu plano de {exam} se adaptou. 10 minutos bastam." },
    ko: { title: "멈춘 곳에서 다시 시작해요", body: "{exam} 계획이 새로 맞춰졌어요. 10분이면 충분해요." },
    ja: { title: "続きから再開しましょう", body: "{exam}プランを調整しました。10分で十分です。" },
    hi: { title: "जहाँ छोड़ा था वहीं से शुरू करें", body: "आपका {exam} प्लान अपडेट हो गया है। 10 मिनट काफ़ी हैं।" }
  },
  offer_expiring: {
    en: { title: "Your {count}% offer ends soon", body: "Premium at the discounted first-year price, only for a few more hours." },
    tr: { title: "%{count} indirimin yakında bitiyor", body: "İlk yıl indirimli Premium, sadece birkaç saat daha." },
    de: { title: "Dein {count} %-Angebot endet bald", body: "Premium zum reduzierten ersten Jahr – nur noch wenige Stunden." },
    es: { title: "Tu oferta del {count} % termina pronto", body: "Premium con primer año rebajado, solo unas horas más." },
    fr: { title: "Ton offre -{count} % se termine bientôt", body: "Premium à prix réduit la 1re année, encore quelques heures." },
    pt: { title: "Sua oferta de {count}% termina em breve", body: "Premium com primeiro ano com desconto, só mais algumas horas." },
    ko: { title: "{count}% 할인이 곧 끝나요", body: "첫해 할인 프리미엄, 몇 시간 남지 않았어요." },
    ja: { title: "{count}%オフがまもなく終了", body: "初年度割引のPremiumはあと数時間です。" },
    hi: { title: "आपका {count}% ऑफ़र जल्द खत्म होगा", body: "पहले साल छूट वाला Premium, बस कुछ घंटे और।" }
  }
};

export const REMINDER_ROUTE: Record<ReminderKind, string> = {
  daily: "today",
  streak_at_risk: "today",
  review_due: "review",
  comeback: "today",
  offer_expiring: "paywall"
};

export function reminderText(kind: ReminderKind, language: string, vars: Record<string, string>): Copy {
  const lang = language.split("-")[0].toLowerCase();
  const source = REMINDER_COPY[kind][lang] ?? REMINDER_COPY[kind].en;
  const fill = (text: string) => text.replace(/\{(\w+)\}/g, (_, key) => vars[key] ?? "");
  return { title: fill(source.title), body: fill(source.body) };
}

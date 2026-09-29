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
    hi: { title: "आज का {exam} प्लान तैयार है", body: "एक छोटा सत्र भी आपकी प्रगति बनाए रखता है।" },
    it: { title: "Il tuo piano {exam} è pronto", body: "Una breve sessione oggi mantiene vivi i tuoi progressi." },
    "pt-PT": { title: "O teu plano de {exam} está pronto", body: "Uma sessão curta hoje mantém o teu progresso." },
    ru: { title: "Ваш план {exam} готов", body: "Даже короткое занятие сегодня сохранит ваш прогресс." },
    pl: { title: "Twój plan {exam} jest gotowy", body: "Krótka sesja dziś utrzyma Twoje postępy." },
    sv: { title: "Din {exam}-plan är klar", body: "Ett kort pass idag håller dina framsteg igång." },
    nb: { title: "{exam}-planen din er klar", body: "En kort økt i dag holder fremgangen i gang." },
    nl: { title: "Je {exam}-plan staat klaar", body: "Een korte sessie vandaag houdt je voortgang op gang." },
    ar: { title: "خطة {exam} جاهزة", body: "جلسة قصيرة اليوم تحافظ على تقدمك." },
    "zh-Hans": { title: "你的 {exam} 计划已就绪", body: "今天学一小会儿,进度就不会中断。" },
    "zh-Hant": { title: "你的 {exam} 計畫已準備好", body: "今天讀一小段,進度就不會中斷。" },
    id: { title: "Rencana {exam}-mu sudah siap", body: "Sesi singkat hari ini menjaga progresmu tetap jalan." }
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
    hi: { title: "अपनी {streak} दिन की स्ट्रीक बचाएँ 🔥", body: "आज एक छोटा सत्र और स्ट्रीक जारी रहेगी।" },
    it: { title: "Salva la tua serie di {streak} giorni 🔥", body: "Una sessione veloce oggi e resta viva." },
    "pt-PT": { title: "Mantém a tua sequência de {streak} dias 🔥", body: "Uma sessão rápida hoje e ela continua." },
    ru: { title: "Сохраните серию из {streak} дн. 🔥", body: "Одно короткое занятие сегодня — и серия продолжится." },
    pl: { title: "Utrzymaj serię {streak} dni 🔥", body: "Jedna szybka sesja dziś i seria trwa dalej." },
    sv: { title: "Behåll din svit på {streak} dagar 🔥", body: "Ett snabbt pass idag så lever den vidare." },
    nb: { title: "Behold rekken på {streak} dager 🔥", body: "Én rask økt i dag, så holder den." },
    nl: { title: "Houd je reeks van {streak} dagen vast 🔥", body: "Eén korte sessie vandaag en hij blijft staan." },
    ar: { title: "حافظ على سلسلة {streak} يومًا 🔥", body: "جلسة سريعة واحدة اليوم وتستمر السلسلة." },
    "zh-Hans": { title: "保住你的 {streak} 天连续记录 🔥", body: "今天学一小会儿,记录就能延续。" },
    "zh-Hant": { title: "守住你的 {streak} 天連續紀錄 🔥", body: "今天讀一小段,紀錄就能延續。" },
    id: { title: "Jaga rekor {streak} hari beruntunmu 🔥", body: "Satu sesi singkat hari ini dan rekormu tetap jalan." }
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
    hi: { title: "{count} टॉपिक दोहराने के लिए तैयार", body: "अभी दोहराना इन्हें याद रखने का सबसे तेज़ तरीका है।" },
    it: { title: "{count} argomenti da ripassare", body: "Ripassare adesso è il modo più rapido per fissarli." },
    "pt-PT": { title: "{count} temas prontos para rever", body: "Rever agora é a forma mais rápida de os fixar." },
    ru: { title: "Тем к повторению: {count}", body: "Повторить сейчас — самый быстрый способ закрепить." },
    pl: { title: "Tematy do powtórki: {count}", body: "Powtórka teraz to najszybszy sposób, by je utrwalić." },
    sv: { title: "{count} ämnen är redo för repetition", body: "Att repetera nu är snabbaste sättet att befästa dem." },
    nb: { title: "{count} temaer er klare for repetisjon", body: "Å repetere nå er raskeste vei til å feste dem." },
    nl: { title: "{count} onderwerpen klaar om te herhalen", body: "Nu herhalen is de snelste manier om ze vast te zetten." },
    ar: { title: "{count} مواضيع جاهزة للمراجعة", body: "المراجعة الآن هي أسرع طريقة لتثبيتها." },
    "zh-Hans": { title: "有 {count} 个知识点该复习了", body: "现在复习,记得最牢。" },
    "zh-Hant": { title: "有 {count} 個觀念該複習了", body: "現在複習,記得最牢。" },
    id: { title: "{count} topik siap diulang", body: "Mengulang sekarang cara tercepat untuk mengingatnya." }
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
    hi: { title: "जहाँ छोड़ा था वहीं से शुरू करें", body: "आपका {exam} प्लान अपडेट हो गया है। 10 मिनट काफ़ी हैं।" },
    it: { title: "Riprendi da dove avevi lasciato", body: "Il tuo piano {exam} si è adattato. Bastano 10 minuti." },
    "pt-PT": { title: "Continua onde paraste", body: "O teu plano de {exam} adaptou-se. Bastam 10 minutos." },
    ru: { title: "Продолжите с того места, где остановились", body: "Ваш план {exam} обновился. Хватит 10 минут." },
    pl: { title: "Wróć tam, gdzie skończyłeś", body: "Twój plan {exam} się dostosował. Wystarczy 10 minut." },
    sv: { title: "Fortsätt där du slutade", body: "Din {exam}-plan har anpassats. 10 minuter räcker." },
    nb: { title: "Fortsett der du slapp", body: "{exam}-planen din er tilpasset. 10 minutter holder." },
    nl: { title: "Ga verder waar je gebleven was", body: "Je {exam}-plan is aangepast. 10 minuten is genoeg." },
    ar: { title: "تابع من حيث توقفت", body: "تكيّفت خطة {exam} أثناء غيابك. تكفي 10 دقائق." },
    "zh-Hans": { title: "从上次停下的地方继续", body: "你的 {exam} 计划已经更新,10 分钟就够。" },
    "zh-Hant": { title: "從上次停下的地方繼續", body: "你的 {exam} 計畫已經更新,10 分鐘就夠。" },
    id: { title: "Lanjutkan dari terakhir kali", body: "Rencana {exam}-mu sudah menyesuaikan. 10 menit cukup." }
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
    hi: { title: "आपका {count}% ऑफ़र जल्द खत्म होगा", body: "पहले साल छूट वाला Premium, बस कुछ घंटे और।" },
    it: { title: "La tua offerta del {count}% sta per scadere", body: "Premium con il primo anno scontato, solo per poche ore." },
    "pt-PT": { title: "A tua oferta de {count}% está a terminar", body: "Premium com o primeiro ano com desconto, só por mais algumas horas." },
    ru: { title: "Скидка {count}% скоро закончится", body: "Premium со скидкой на первый год — осталось несколько часов." },
    pl: { title: "Twoja oferta -{count}% wkrótce wygaśnie", body: "Premium z tańszym pierwszym rokiem — jeszcze tylko kilka godzin." },
    sv: { title: "Ditt erbjudande på {count} % går snart ut", body: "Premium med rabatterat första år, bara några timmar kvar." },
    nb: { title: "Tilbudet på {count} % går snart ut", body: "Premium med rabattert første år, bare noen timer igjen." },
    nl: { title: "Je aanbieding van {count}% verloopt bijna", body: "Premium met korting op het eerste jaar, nog maar een paar uur." },
    ar: { title: "عرض خصم {count}% ينتهي قريبًا", body: "Premium بخصم على السنة الأولى لبضع ساعات فقط." },
    "zh-Hans": { title: "{count}% 优惠即将结束", body: "首年优惠的 Premium,只剩几个小时。" },
    "zh-Hant": { title: "{count}% 優惠即將結束", body: "首年優惠的 Premium,只剩幾個小時。" },
    id: { title: "Penawaran {count}% segera berakhir", body: "Premium dengan diskon tahun pertama, tinggal beberapa jam." }
  }
};

export const REMINDER_ROUTE: Record<ReminderKind, string> = {
  daily: "today",
  streak_at_risk: "today",
  review_due: "review",
  comeback: "today",
  offer_expiring: "paywall"
};

/** Maps a device locale tag (e.g. "pt-PT", "zh-Hant-TW", "nn") to a copy key. */
export function copyLanguage(language: string): string {
  const parts = language.replace(/_/g, "-").split("-");
  const base = parts[0].toLowerCase();
  const rest = parts.slice(1).map(part => part.toUpperCase());
  if (base === "zh") return rest.some(p => ["HANT", "TW", "HK", "MO"].includes(p)) ? "zh-Hant" : "zh-Hans";
  if (base === "pt") return rest.includes("PT") ? "pt-PT" : "pt";
  if (["nb", "no", "nn"].includes(base)) return "nb";
  if (base === "in") return "id";
  return base;
}

export function reminderText(kind: ReminderKind, language: string, vars: Record<string, string>): Copy {
  const source = REMINDER_COPY[kind][copyLanguage(language)] ?? REMINDER_COPY[kind].en;
  const fill = (text: string) => text.replace(/\{(\w+)\}/g, (_, key) => vars[key] ?? "");
  return { title: fill(source.title), body: fill(source.body) };
}

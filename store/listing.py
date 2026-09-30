"""Generates App Store and Google Play listings for all 20 languages.

Output uses the fastlane layout, which asc and Play upload tooling read:
  store/ios/metadata/<asc-locale>/*.txt
  store/android/metadata/android/<play-locale>/*.txt

Usage: python3 store/listing.py   (fails if any field exceeds a store limit)
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent

# Hosted on Firebase Hosting (store/legal/build.py + firebase deploy --only hosting).
TERMS_URL = "https://examly-study.web.app/terms"
PRIVACY_URL = "https://examly-study.web.app/privacy"
SUPPORT_URL = "https://examly-study.web.app/support"
MARKETING_URL = "https://examly-study.web.app"

# app code -> (App Store Connect locale, Google Play locale)
LOCALES = {
    "en": ("en-US", "en-US"), "tr": ("tr", "tr-TR"), "de": ("de-DE", "de-DE"),
    "fr": ("fr-FR", "fr-FR"), "es": ("es-ES", "es-ES"), "it": ("it", "it-IT"),
    "pt": ("pt-BR", "pt-BR"), "pt-PT": ("pt-PT", "pt-PT"), "nl": ("nl-NL", "nl-NL"),
    "sv": ("sv", "sv-SE"), "nb": ("no", "no-NO"), "pl": ("pl", "pl-PL"),
    "ru": ("ru", "ru-RU"), "ar": ("ar-SA", "ar"), "hi": ("hi", "hi-IN"),
    "id": ("id", "id"), "ja": ("ja", "ja-JP"), "ko": ("ko", "ko-KR"),
    "zh-Hans": ("zh-Hans", "zh-CN"), "zh-Hant": ("zh-Hant", "zh-TW"),
}

LIMITS = {"name": 30, "subtitle": 30, "keywords": 100, "promotional_text": 170,
          "title": 30, "short_description": 80, "description": 4000, "full_description": 4000}

L = {}

L["en"] = dict(
    name="Examly: AI Study Planner",
    sub="Exam prep with an AI tutor",
    kw="exam,prep,sat,ielts,toefl,study,planner,quiz,flashcards,tutor,homework,test,revision,pomodoro",
    promo="Your personal exam plan in 2 minutes: adaptive practice, mistake review and an AI tutor that explains until it clicks.",
    short="Adaptive exam prep: daily plan, practice, mistake review and an AI tutor.",
    intro="Examly turns exam prep into a short, clear plan for every day. Pick your exam, take a 5-question diagnostic, and get a personal study week that adapts as you learn.",
    feats=[
        "Personal daily plan built from your diagnostic, mastery and recent mistakes",
        "Adaptive practice with exam-style questions for 20+ exams, including SAT, ACT, IELTS, TOEFL, YKS, A-Level and more",
        "Error DNA: see the patterns that cost you points and fix them",
        "AI tutor that explains step by step, simpler when you need it, and solves questions from a photo",
        "Turn your notes and PDFs into summaries and quizzes",
        "Flashcards with spaced repetition, timed mock exams and focus sessions",
        "Home screen widgets: your streak and a question of the day you can answer without opening the app",
    ],
    subnote="Examly is free to start. Premium unlocks unlimited personalized practice, the advanced AI tutor, voice tutor and unlimited study materials. Optional credit packs are used only for AI image and video explanations. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period; manage them in your store account settings.",
    legal="Terms", privacy="Privacy",
    notes="Welcome to Examly! Personal study plans, adaptive practice, an AI tutor, widgets and 20 languages.",
)

L["tr"] = dict(
    name="Examly: Sınav Hazırlık & AI",
    sub="Yapay zekâ destekli çalışma",
    kw="yks,lgs,kpss,ales,dgs,sınav,deneme,soru,test,ders,çalışma,planı,özel,hoca,soru çözme,tyt,ayt",
    promo="2 dakikada kişisel sınav planın hazır: uyarlanabilir sorular, hata tekrarı ve anlayana kadar anlatan yapay zekâ öğretmen.",
    short="YKS, LGS, KPSS ve daha fazlası için kişisel plan, soru ve AI öğretmen.",
    intro="Examly sınava hazırlığı her gün için kısa ve net bir plana dönüştürür. Sınavını seç, 5 soruluk seviye testini çöz ve öğrendikçe kendini güncelleyen kişisel çalışma haftanı al.",
    feats=[
        "Seviye testine, ustalığına ve son hatalarına göre hazırlanan günlük plan",
        "YKS, LGS, KPSS, ALES, DGS, SAT, IELTS ve 20'den fazla sınav için sınav tarzı uyarlanabilir sorular",
        "Hata DNA'sı: puan kaybettiren kalıplarını gör ve düzelt",
        "Adım adım, gerektiğinde daha basit anlatan ve fotoğraftan soru çözen yapay zekâ öğretmen",
        "Notlarını ve PDF'lerini özetlere ve testlere dönüştür",
        "Aralıklı tekrarlı kartlar, süreli deneme sınavları ve odak seansları",
        "Ana ekran widget'ları: serin ve uygulamayı açmadan cevaplayabileceğin günün sorusu",
    ],
    subnote="Examly'ye ücretsiz başlarsın. Premium; sınırsız kişisel pratik, gelişmiş yapay zekâ öğretmen, sesli öğretmen ve sınırsız çalışma materyali sunar. İsteğe bağlı kredi paketleri yalnızca yapay zekâ görsel ve video anlatımları için kullanılır. Abonelik, dönem bitiminden en az 24 saat önce iptal edilmezse otomatik yenilenir; mağaza hesap ayarlarından yönetebilirsin.",
    legal="Kullanım Koşulları", privacy="Gizlilik",
    notes="Examly'ye hoş geldin! Kişisel çalışma planı, uyarlanabilir sorular, yapay zekâ öğretmen, widget'lar ve 20 dil.",
)

L["de"] = dict(
    name="Examly: KI-Lernplaner",
    sub="Prüfungsvorbereitung mit KI",
    kw="abitur,prüfung,lernen,lernplan,nachhilfe,karteikarten,quiz,test,ielts,toefl,schule,mathe,übung",
    promo="Dein persönlicher Prüfungsplan in 2 Minuten: adaptive Übungen, Fehleranalyse und ein KI-Tutor, der erklärt, bis es klick macht.",
    short="Adaptive Prüfungsvorbereitung: Tagesplan, Übungen, Fehleranalyse, KI-Tutor.",
    intro="Examly macht aus Prüfungsvorbereitung einen kurzen, klaren Plan für jeden Tag. Wähle deine Prüfung, mach einen Einstufungstest mit 5 Fragen und erhalte eine persönliche Lernwoche, die sich mit dir weiterentwickelt.",
    feats=[
        "Persönlicher Tagesplan aus Einstufung, Lernstand und aktuellen Fehlern",
        "Adaptive Übungen im Prüfungsstil für über 20 Prüfungen, darunter Abitur, IELTS, TOEFL und SAT",
        "Error DNA: Erkenne die Muster, die dich Punkte kosten, und behebe sie",
        "KI-Tutor, der Schritt für Schritt erklärt, auf Wunsch einfacher, und Aufgaben per Foto löst",
        "Mach aus Notizen und PDFs Zusammenfassungen und Quizze",
        "Karteikarten mit Wiederholung in Intervallen, Probeprüfungen auf Zeit und Fokus-Sessions",
        "Widgets für den Home-Bildschirm: deine Serie und eine Frage des Tages, direkt beantwortbar",
    ],
    subnote="Examly kannst du kostenlos starten. Premium schaltet unbegrenztes personalisiertes Üben, den erweiterten KI-Tutor, den Sprach-Tutor und unbegrenzte Lernmaterialien frei. Optionale Credit-Pakete werden nur für KI-Bild- und Video-Erklärungen verwendet. Abos verlängern sich automatisch, wenn sie nicht mindestens 24 Stunden vor Ablauf gekündigt werden; verwalte sie in den Einstellungen deines Store-Kontos.",
    legal="Nutzungsbedingungen", privacy="Datenschutz",
    notes="Willkommen bei Examly! Persönliche Lernpläne, adaptive Übungen, KI-Tutor, Widgets und 20 Sprachen.",
)

L["fr"] = dict(
    name="Examly : révisions avec IA",
    sub="Prépa d’examens avec tuteur IA",
    kw="bac,examen,révision,révisions,planning,quiz,fiches,prof,soutien,ielts,toefl,sat,maths,exercices",
    promo="Ton plan de révision personnel en 2 minutes : exercices adaptatifs, analyse des erreurs et un tuteur IA qui explique jusqu’à ce que tu comprennes.",
    short="Révisions adaptatives : plan du jour, exercices, erreurs et tuteur IA.",
    intro="Examly transforme la préparation d’un examen en un plan court et clair pour chaque jour. Choisis ton examen, fais un test de niveau de 5 questions et obtiens une semaine de révision qui s’adapte à tes progrès.",
    feats=[
        "Plan quotidien personnel basé sur ton test de niveau, ta maîtrise et tes erreurs récentes",
        "Exercices adaptatifs type examen pour plus de 20 examens, dont le bac, l’IELTS, le TOEFL et le SAT",
        "Error DNA : repère les erreurs qui te coûtent des points et corrige-les",
        "Tuteur IA qui explique étape par étape, plus simplement si besoin, et résout un exercice en photo",
        "Transforme tes notes et PDF en résumés et en quiz",
        "Fiches avec répétition espacée, examens blancs chronométrés et sessions de concentration",
        "Widgets d’écran d’accueil : ta série et une question du jour à laquelle répondre sans ouvrir l’app",
    ],
    subnote="Examly est gratuit pour commencer. Premium débloque les exercices personnalisés illimités, le tuteur IA avancé, le tuteur vocal et les supports de cours illimités. Les packs de crédits facultatifs servent uniquement aux explications IA en image et en vidéo. L’abonnement se renouvelle automatiquement s’il n’est pas résilié au moins 24 heures avant la fin de la période ; gère-le dans les réglages de ton compte store.",
    legal="Conditions d’utilisation", privacy="Confidentialité",
    notes="Bienvenue sur Examly ! Plans de révision personnels, exercices adaptatifs, tuteur IA, widgets et 20 langues.",
)

L["es"] = dict(
    name="Examly: planificador con IA",
    sub="Prepara exámenes con tutor IA",
    kw="selectividad,pau,ebau,examen,estudiar,estudio,quiz,tarjetas,tutor,ielts,toefl,test,repaso,deberes",
    promo="Tu plan de estudio personal en 2 minutos: práctica adaptativa, repaso de errores y un tutor IA que explica hasta que lo entiendas.",
    short="Preparación adaptativa: plan diario, práctica, errores y tutor con IA.",
    intro="Examly convierte la preparación de un examen en un plan breve y claro para cada día. Elige tu examen, haz un diagnóstico de 5 preguntas y recibe una semana de estudio personal que se adapta a medida que aprendes.",
    feats=[
        "Plan diario personal basado en tu diagnóstico, tu dominio y tus errores recientes",
        "Práctica adaptativa tipo examen para más de 20 exámenes, como la PAU/EBAU, IELTS, TOEFL y SAT",
        "Error DNA: descubre los patrones que te hacen perder puntos y corrígelos",
        "Tutor IA que explica paso a paso, más simple si lo necesitas, y resuelve preguntas desde una foto",
        "Convierte tus apuntes y PDF en resúmenes y cuestionarios",
        "Tarjetas con repetición espaciada, simulacros cronometrados y sesiones de concentración",
        "Widgets en la pantalla de inicio: tu racha y una pregunta del día que puedes responder sin abrir la app",
    ],
    subnote="Examly es gratis para empezar. Premium desbloquea práctica personalizada ilimitada, el tutor IA avanzado, el tutor de voz y materiales de estudio ilimitados. Los paquetes de créditos opcionales solo se usan para explicaciones con imagen y vídeo generados por IA. La suscripción se renueva automáticamente salvo que la canceles al menos 24 horas antes del final del periodo; gestiónala en los ajustes de tu cuenta de la tienda.",
    legal="Términos", privacy="Privacidad",
    notes="¡Bienvenido a Examly! Planes de estudio personales, práctica adaptativa, tutor IA, widgets y 20 idiomas.",
)

L["it"] = dict(
    name="Examly: studio con IA",
    sub="Prepara gli esami con l’IA",
    kw="esame,esami,studio,studiare,test,quiz,flashcard,tutor,ripasso,ielts,toefl,sat,compiti,matematica",
    promo="Il tuo piano di studio personale in 2 minuti: esercizi adattivi, ripasso degli errori e un tutor IA che spiega finché non è chiaro.",
    short="Preparazione adattiva: piano del giorno, esercizi, errori e tutor IA.",
    intro="Examly trasforma la preparazione agli esami in un piano breve e chiaro per ogni giorno. Scegli il tuo esame, fai un test diagnostico di 5 domande e ricevi una settimana di studio personale che si adatta ai tuoi progressi.",
    feats=[
        "Piano giornaliero personale basato su test diagnostico, padronanza ed errori recenti",
        "Esercizi adattivi in stile esame per oltre 20 esami, tra cui IELTS, TOEFL, SAT e altri",
        "Error DNA: scopri gli schemi che ti fanno perdere punti e correggili",
        "Tutor IA che spiega passo dopo passo, più semplice se serve, e risolve le domande da una foto",
        "Trasforma appunti e PDF in riassunti e quiz",
        "Flashcard con ripetizione dilazionata, simulazioni a tempo e sessioni di focus",
        "Widget nella schermata Home: la tua serie e una domanda del giorno a cui rispondere senza aprire l’app",
    ],
    subnote="Examly è gratis per iniziare. Premium sblocca esercizi personalizzati illimitati, il tutor IA avanzato, il tutor vocale e materiali di studio illimitati. I pacchetti di crediti facoltativi servono solo per spiegazioni IA con immagini e video. L’abbonamento si rinnova automaticamente se non viene disdetto almeno 24 ore prima della fine del periodo; gestiscilo dalle impostazioni del tuo account dello store.",
    legal="Termini", privacy="Privacy",
    notes="Benvenuto in Examly! Piani di studio personali, esercizi adattivi, tutor IA, widget e 20 lingue.",
)

L["pt"] = dict(
    name="Examly: estudos com IA",
    sub="Prepare-se com um tutor de IA",
    kw="enem,vestibular,prova,simulado,estudar,estudo,questões,flashcards,tutor,redação,ielts,toefl,revisão",
    promo="Seu plano de estudo pessoal em 2 minutos: questões adaptativas, revisão de erros e um tutor de IA que explica até você entender.",
    short="Estudo adaptativo: plano do dia, questões, revisão de erros e tutor com IA.",
    intro="O Examly transforma a preparação para provas em um plano curto e claro para cada dia. Escolha sua prova, faça um diagnóstico de 5 questões e receba uma semana de estudo personalizada que se adapta enquanto você aprende.",
    feats=[
        "Plano diário personalizado com base no diagnóstico, no seu domínio e nos erros recentes",
        "Questões adaptativas no estilo da prova para mais de 20 exames, como ENEM, IELTS, TOEFL e SAT",
        "Error DNA: veja os padrões que tiram seus pontos e corrija-os",
        "Tutor de IA que explica passo a passo, de forma mais simples quando precisar, e resolve questões por foto",
        "Transforme suas anotações e PDFs em resumos e quizzes",
        "Flashcards com repetição espaçada, simulados cronometrados e sessões de foco",
        "Widgets na tela inicial: sua sequência e uma pergunta do dia para responder sem abrir o app",
    ],
    subnote="O Examly é gratuito para começar. O Premium libera prática personalizada ilimitada, o tutor de IA avançado, o tutor por voz e materiais de estudo ilimitados. Os pacotes de créditos opcionais são usados apenas para explicações em imagem e vídeo geradas por IA. A assinatura é renovada automaticamente, a menos que seja cancelada pelo menos 24 horas antes do fim do período; gerencie nas configurações da sua conta da loja.",
    legal="Termos", privacy="Privacidade",
    notes="Boas-vindas ao Examly! Planos de estudo pessoais, questões adaptativas, tutor de IA, widgets e 20 idiomas.",
)

L["pt-PT"] = dict(
    name="Examly: estudo com IA",
    sub="Prepara-te com um tutor de IA",
    kw="exame,exames,estudar,estudo,testes,perguntas,flashcards,explicador,ielts,toefl,sat,revisão",
    promo="O teu plano de estudo pessoal em 2 minutos: prática adaptativa, revisão de erros e um tutor de IA que explica até perceberes.",
    short="Estudo adaptativo: plano do dia, prática, revisão de erros e tutor com IA.",
    intro="O Examly transforma a preparação para exames num plano curto e claro para cada dia. Escolhe o teu exame, faz um diagnóstico de 5 perguntas e recebe uma semana de estudo pessoal que se adapta à medida que aprendes.",
    feats=[
        "Plano diário pessoal com base no diagnóstico, no teu domínio e nos erros recentes",
        "Prática adaptativa tipo exame para mais de 20 exames, incluindo IELTS, TOEFL e SAT",
        "Error DNA: vê os padrões que te fazem perder pontos e corrige-os",
        "Tutor de IA que explica passo a passo, de forma mais simples quando precisares, e resolve perguntas a partir de uma foto",
        "Transforma os teus apontamentos e PDFs em resumos e testes",
        "Cartões com repetição espaçada, simulações cronometradas e sessões de foco",
        "Widgets no ecrã principal: a tua sequência e uma pergunta do dia para responderes sem abrir a app",
    ],
    subnote="O Examly é gratuito para começar. O Premium desbloqueia prática personalizada ilimitada, o tutor de IA avançado, o tutor de voz e materiais de estudo ilimitados. Os pacotes de créditos opcionais são usados apenas para explicações em imagem e vídeo geradas por IA. A subscrição renova-se automaticamente, exceto se for cancelada pelo menos 24 horas antes do fim do período; gere-a nas definições da tua conta da loja.",
    legal="Termos", privacy="Privacidade",
    notes="Bem-vindo ao Examly! Planos de estudo pessoais, prática adaptativa, tutor de IA, widgets e 20 idiomas.",
)

L["nl"] = dict(
    name="Examly: AI-studieplanner",
    sub="Examens voorbereiden met AI",
    kw="examen,toets,studeren,leren,oefenen,quiz,flashcards,bijles,ielts,toefl,sat,huiswerk,wiskunde",
    promo="Je persoonlijke studieplan in 2 minuten: adaptief oefenen, fouten herhalen en een AI-tutor die uitlegt tot het klikt.",
    short="Adaptieve examentraining: dagplan, oefenen, foutenanalyse en AI-tutor.",
    intro="Examly maakt van examenvoorbereiding een kort, duidelijk plan voor elke dag. Kies je examen, doe een instaptoets van 5 vragen en krijg een persoonlijke studieweek die meegroeit terwijl je leert.",
    feats=[
        "Persoonlijk dagplan op basis van je instaptoets, beheersing en recente fouten",
        "Adaptief oefenen met examenvragen voor meer dan 20 examens, waaronder IELTS, TOEFL en SAT",
        "Error DNA: zie welke patronen je punten kosten en los ze op",
        "AI-tutor die stap voor stap uitlegt, simpeler als dat nodig is, en vragen oplost vanaf een foto",
        "Maak van je aantekeningen en pdf’s samenvattingen en quizzen",
        "Flashcards met gespreide herhaling, proefexamens op tijd en focussessies",
        "Widgets op je beginscherm: je reeks en een vraag van de dag die je beantwoordt zonder de app te openen",
    ],
    subnote="Examly is gratis om te beginnen. Premium ontgrendelt onbeperkt persoonlijk oefenen, de geavanceerde AI-tutor, de spraaktutor en onbeperkt studiemateriaal. Optionele creditpakketten worden alleen gebruikt voor AI-uitleg met afbeeldingen en video. Abonnementen worden automatisch verlengd tenzij je ten minste 24 uur voor het einde van de periode opzegt; beheer ze in de instellingen van je store-account.",
    legal="Voorwaarden", privacy="Privacy",
    notes="Welkom bij Examly! Persoonlijke studieplannen, adaptief oefenen, AI-tutor, widgets en 20 talen.",
)

L["sv"] = dict(
    name="Examly: AI-studieplanerare",
    sub="Plugga till prov med AI",
    kw="prov,tenta,plugga,studier,läxhjälp,quiz,flashcards,handledare,ielts,toefl,sat,matte,övning",
    promo="Din personliga pluggplan på 2 minuter: adaptiva övningar, genomgång av misstag och en AI-handledare som förklarar tills det sitter.",
    short="Adaptiv provträning: dagsplan, övningar, misstag och AI-handledare.",
    intro="Examly gör provförberedelser till en kort och tydlig plan för varje dag. Välj ditt prov, gör ett diagnostiskt test med 5 frågor och få en personlig pluggvecka som anpassas medan du lär dig.",
    feats=[
        "Personlig dagsplan utifrån diagnostiskt test, behärskning och senaste misstag",
        "Adaptiva provliknande övningar för över 20 prov, bland annat IELTS, TOEFL och SAT",
        "Error DNA: se mönstren som kostar dig poäng och rätta till dem",
        "AI-handledare som förklarar steg för steg, enklare när du behöver, och löser uppgifter från ett foto",
        "Gör dina anteckningar och PDF:er till sammanfattningar och quiz",
        "Flashcards med repetition i intervaller, övningsprov på tid och fokuspass",
        "Widgetar på hemskärmen: din svit och en dagens fråga som du svarar på utan att öppna appen",
    ],
    subnote="Examly är gratis att börja med. Premium låser upp obegränsad personlig övning, den avancerade AI-handledaren, röst-handledaren och obegränsat studiematerial. Valfria kreditpaket används bara för AI-förklaringar med bild och video. Prenumerationen förnyas automatiskt om den inte sägs upp minst 24 timmar före periodens slut; hantera den i inställningarna för ditt butikskonto.",
    legal="Villkor", privacy="Integritet",
    notes="Välkommen till Examly! Personliga pluggplaner, adaptiva övningar, AI-handledare, widgetar och 20 språk.",
)

L["nb"] = dict(
    name="Examly: KI-studieplanlegger",
    sub="Eksamensforberedelse med KI",
    kw="eksamen,prøve,studere,lekser,leksehjelp,quiz,kortstokk,veileder,ielts,toefl,matte,øving,repetisjon",
    promo="Den personlige studieplanen din på 2 minutter: tilpasset øving, gjennomgang av feil og en KI-veileder som forklarer til det sitter.",
    short="Tilpasset eksamensøving: dagsplan, øving, feilanalyse og KI-veileder.",
    intro="Examly gjør eksamensforberedelser om til en kort og tydelig plan for hver dag. Velg eksamen, ta en kartlegging med 5 spørsmål og få en personlig studieuke som tilpasses mens du lærer.",
    feats=[
        "Personlig dagsplan basert på kartlegging, mestring og nylige feil",
        "Tilpasset øving med eksamenslignende spørsmål for over 20 eksamener, blant annet IELTS, TOEFL og SAT",
        "Error DNA: se mønstrene som koster deg poeng, og rett dem opp",
        "KI-veileder som forklarer steg for steg, enklere når du trenger det, og løser oppgaver fra et bilde",
        "Gjør notater og PDF-er om til sammendrag og quiz",
        "Kortstokker med repetisjon i intervaller, prøveeksamener på tid og fokusøkter",
        "Moduler på hjemskjermen: rekken din og dagens spørsmål som du kan svare på uten å åpne appen",
    ],
    subnote="Examly er gratis å starte med. Premium låser opp ubegrenset personlig øving, den avanserte KI-veilederen, stemmeveilederen og ubegrenset studiemateriale. Valgfrie kredittpakker brukes bare til KI-forklaringer med bilde og video. Abonnementet fornyes automatisk med mindre det sies opp minst 24 timer før perioden utløper; administrer det i innstillingene for butikkontoen din.",
    legal="Vilkår", privacy="Personvern",
    notes="Velkommen til Examly! Personlige studieplaner, tilpasset øving, KI-veileder, moduler og 20 språk.",
)

L["pl"] = dict(
    name="Examly: planer nauki z AI",
    sub="Do egzaminów z tutorem AI",
    kw="egzamin,egzaminy,nauka,uczyć,quiz,fiszki,korepetycje,ielts,toefl,sat,matematyka,testy,powtórka",
    promo="Twój osobisty plan nauki w 2 minuty: adaptacyjne ćwiczenia, powtórka błędów i tutor AI, który tłumaczy, aż zrozumiesz.",
    short="Adaptacyjne przygotowanie: plan dnia, ćwiczenia, błędy i tutor AI.",
    intro="Examly zamienia przygotowania do egzaminu w krótki, jasny plan na każdy dzień. Wybierz egzamin, rozwiąż diagnozę z 5 pytań i otrzymaj osobisty tydzień nauki, który dopasowuje się do Twoich postępów.",
    feats=[
        "Osobisty plan dnia na podstawie diagnozy, poziomu opanowania i ostatnich błędów",
        "Adaptacyjne ćwiczenia w stylu egzaminu dla ponad 20 egzaminów, m.in. IELTS, TOEFL i SAT",
        "Error DNA: zobacz wzorce, które kosztują Cię punkty, i napraw je",
        "Tutor AI, który tłumaczy krok po kroku, prościej, gdy trzeba, i rozwiązuje zadania ze zdjęcia",
        "Zamieniaj notatki i pliki PDF w streszczenia i quizy",
        "Fiszki z powtórkami rozłożonymi w czasie, egzaminy próbne na czas i sesje skupienia",
        "Widżety na ekranie głównym: Twoja seria i pytanie dnia, na które odpowiesz bez otwierania aplikacji",
    ],
    subnote="Examly możesz zacząć za darmo. Premium odblokowuje nielimitowane ćwiczenia, zaawansowanego tutora AI, tutora głosowego i nielimitowane materiały. Opcjonalne pakiety kredytów służą wyłącznie do wyjaśnień AI w formie obrazów i filmów. Subskrypcja odnawia się automatycznie, jeśli nie zostanie anulowana co najmniej 24 godziny przed końcem okresu; zarządzaj nią w ustawieniach konta sklepu.",
    legal="Regulamin", privacy="Prywatność",
    notes="Witamy w Examly! Osobiste plany nauki, adaptacyjne ćwiczenia, tutor AI, widżety i 20 języków.",
)

L["ru"] = dict(
    name="Examly: ИИ-план подготовки",
    sub="Подготовка к экзаменам с ИИ",
    kw="экзамен,подготовка,тесты,репетитор,карточки,учёба,ielts,toefl,sat,математика,задачи,повторение",
    promo="Личный план подготовки за 2 минуты: адаптивная практика, разбор ошибок и ИИ-репетитор, который объясняет, пока не станет понятно.",
    short="Адаптивная подготовка: план на день, практика, ошибки и ИИ-репетитор.",
    intro="Examly превращает подготовку к экзамену в короткий и понятный план на каждый день. Выберите экзамен, пройдите диагностику из 5 вопросов и получите личную учебную неделю, которая подстраивается под ваш прогресс.",
    feats=[
        "Личный план на день по результатам диагностики, уровню освоения и недавним ошибкам",
        "Адаптивная практика в формате экзамена для 20+ экзаменов, включая IELTS, TOEFL и SAT",
        "Error DNA: увидьте закономерности, из-за которых теряете баллы, и исправьте их",
        "ИИ-репетитор объясняет по шагам, проще — если нужно, и решает задачи по фото",
        "Превращайте конспекты и PDF в краткие выжимки и тесты",
        "Карточки с интервальным повторением, пробные экзамены на время и фокус-сессии",
        "Виджеты на главном экране: ваша серия и вопрос дня, на который можно ответить, не открывая приложение",
    ],
    subnote="Начать пользоваться Examly можно бесплатно. Premium открывает безлимитную персональную практику, продвинутого ИИ-репетитора, голосового репетитора и безлимитные учебные материалы. Дополнительные пакеты кредитов нужны только для ИИ-объяснений с изображениями и видео. Подписка продлевается автоматически, если не отменить её минимум за 24 часа до окончания периода; управлять ею можно в настройках аккаунта магазина.",
    legal="Условия", privacy="Конфиденциальность",
    notes="Добро пожаловать в Examly! Личные учебные планы, адаптивная практика, ИИ-репетитор, виджеты и 20 языков.",
)

L["ar"] = dict(
    name="Examly: مخطط دراسة ذكي",
    sub="استعد للاختبارات مع معلم ذكي",
    kw="اختبار,امتحان,دراسة,مذاكرة,أسئلة,بطاقات,معلم,ielts,toefl,sat,رياضيات,مراجعة,واجبات",
    promo="خطتك الدراسية الشخصية في دقيقتين: تدريب متكيّف ومراجعة للأخطاء ومعلم ذكي يشرح حتى تفهم.",
    short="استعداد متكيّف للاختبارات: خطة يومية وتدريب ومراجعة أخطاء ومعلم ذكي.",
    intro="يحوّل Examly الاستعداد للاختبار إلى خطة قصيرة وواضحة لكل يوم. اختر اختبارك، وأجب عن اختبار تشخيصي من 5 أسئلة، واحصل على أسبوع دراسي شخصي يتكيّف مع تقدمك.",
    feats=[
        "خطة يومية شخصية مبنية على التشخيص ومستوى الإتقان والأخطاء الأخيرة",
        "تدريب متكيّف بأسئلة بأسلوب الاختبار لأكثر من 20 اختبارًا، منها IELTS وTOEFL وSAT",
        "Error DNA: اكتشف الأنماط التي تفقدك الدرجات وعالجها",
        "معلم ذكي يشرح خطوة بخطوة، وبشكل أبسط عند الحاجة، ويحل الأسئلة من صورة",
        "حوّل ملاحظاتك وملفات PDF إلى ملخصات واختبارات قصيرة",
        "بطاقات بمراجعة متباعدة واختبارات تجريبية مؤقتة وجلسات تركيز",
        "أدوات على الشاشة الرئيسية: سلسلتك وسؤال اليوم الذي تجيب عنه دون فتح التطبيق",
    ],
    subnote="يمكنك البدء في Examly مجانًا. يفتح Premium التدريب الشخصي غير المحدود والمعلم الذكي المتقدم والمعلم الصوتي والمواد الدراسية غير المحدودة. تُستخدم حزم الرصيد الاختيارية فقط لشروحات الصور والفيديو بالذكاء الاصطناعي. يتجدد الاشتراك تلقائيًا ما لم يُلغَ قبل 24 ساعة على الأقل من نهاية الفترة، ويمكنك إدارته من إعدادات حسابك في المتجر.",
    legal="الشروط", privacy="الخصوصية",
    notes="مرحبًا بك في Examly! خطط دراسية شخصية وتدريب متكيّف ومعلم ذكي وأدوات للشاشة الرئيسية و20 لغة.",
)

L["hi"] = dict(
    name="Examly: AI स्टडी प्लानर",
    sub="AI ट्यूटर से परीक्षा की तैयारी",
    kw="jee,neet,cuet,परीक्षा,तैयारी,mock,test,quiz,flashcards,tutor,ielts,toefl,गणित,revision",
    promo="2 मिनट में आपका पर्सनल स्टडी प्लान: अडैप्टिव प्रैक्टिस, गलतियों का रिव्यू और एक AI ट्यूटर जो समझ आने तक समझाए।",
    short="JEE, NEET, CUET और अन्य परीक्षाओं के लिए पर्सनल प्लान, प्रैक्टिस और AI ट्यूटर।",
    intro="Examly परीक्षा की तैयारी को हर दिन के लिए छोटे और साफ़ प्लान में बदल देता है। अपनी परीक्षा चुनें, 5 सवालों का डायग्नॉस्टिक दें और एक पर्सनल स्टडी वीक पाएँ जो आपकी प्रगति के साथ बदलता है।",
    feats=[
        "डायग्नॉस्टिक, महारत और हाल की गलतियों पर आधारित पर्सनल डेली प्लान",
        "JEE Main, NEET UG, CUET UG, IELTS, TOEFL समेत 20+ परीक्षाओं के लिए परीक्षा जैसे अडैप्टिव सवाल",
        "Error DNA: देखें कि किन पैटर्न से नंबर कटते हैं और उन्हें सुधारें",
        "AI ट्यूटर जो स्टेप-बाय-स्टेप, ज़रूरत हो तो और आसान समझाए, और फ़ोटो से सवाल हल करे",
        "अपने नोट्स और PDF को सारांश और क्विज़ में बदलें",
        "स्पेस्ड रिपिटिशन वाले फ़्लैशकार्ड, समयबद्ध मॉक टेस्ट और फ़ोकस सेशन",
        "होम स्क्रीन विजेट: आपकी स्ट्रीक और आज का सवाल, जिसका जवाब ऐप खोले बिना दें",
    ],
    subnote="Examly मुफ़्त में शुरू करें। Premium से अनलिमिटेड पर्सनल प्रैक्टिस, एडवांस्ड AI ट्यूटर, वॉइस ट्यूटर और अनलिमिटेड स्टडी मटीरियल मिलते हैं। वैकल्पिक क्रेडिट पैक सिर्फ़ AI इमेज और वीडियो एक्सप्लेनेशन के लिए इस्तेमाल होते हैं। सब्सक्रिप्शन अपने-आप रिन्यू होता है, जब तक अवधि खत्म होने से कम से कम 24 घंटे पहले रद्द न किया जाए; इसे स्टोर अकाउंट सेटिंग में मैनेज करें।",
    legal="शर्तें", privacy="गोपनीयता",
    notes="Examly में आपका स्वागत है! पर्सनल स्टडी प्लान, अडैप्टिव प्रैक्टिस, AI ट्यूटर, विजेट और 20 भाषाएँ।",
)

L["id"] = dict(
    name="Examly: Perencana Belajar AI",
    sub="Siap ujian bersama tutor AI",
    kw="ujian,tryout,belajar,soal,latihan,kuis,flashcard,tutor,ielts,toefl,sat,matematika,pr,bimbel",
    promo="Rencana belajar pribadimu dalam 2 menit: latihan adaptif, ulasan kesalahan, dan tutor AI yang menjelaskan sampai kamu paham.",
    short="Persiapan ujian adaptif: rencana harian, latihan, kesalahan, dan tutor AI.",
    intro="Examly mengubah persiapan ujian menjadi rencana singkat dan jelas setiap hari. Pilih ujianmu, kerjakan tes diagnostik 5 soal, dan dapatkan minggu belajar pribadi yang menyesuaikan progresmu.",
    feats=[
        "Rencana harian pribadi dari hasil diagnostik, penguasaan, dan kesalahan terbaru",
        "Latihan adaptif bergaya ujian untuk 20+ ujian, termasuk IELTS, TOEFL, dan SAT",
        "Error DNA: lihat pola yang membuatmu kehilangan poin dan perbaiki",
        "Tutor AI yang menjelaskan langkah demi langkah, lebih sederhana bila perlu, dan menyelesaikan soal dari foto",
        "Ubah catatan dan PDF menjadi ringkasan dan kuis",
        "Flashcard dengan pengulangan berjeda, tryout berbatas waktu, dan sesi fokus",
        "Widget layar utama: rekor beruntunmu dan soal hari ini yang bisa dijawab tanpa membuka aplikasi",
    ],
    subnote="Examly gratis untuk memulai. Premium membuka latihan pribadi tanpa batas, tutor AI lanjutan, tutor suara, dan materi belajar tanpa batas. Paket kredit opsional hanya dipakai untuk penjelasan gambar dan video buatan AI. Langganan diperpanjang otomatis kecuali dibatalkan paling lambat 24 jam sebelum periode berakhir; kelola di pengaturan akun toko.",
    legal="Ketentuan", privacy="Privasi",
    notes="Selamat datang di Examly! Rencana belajar pribadi, latihan adaptif, tutor AI, widget, dan 20 bahasa.",
)

L["ja"] = dict(
    name="Examly: AI学習プランナー",
    sub="AI家庭教師で試験対策",
    kw="共通テスト,受験,試験,勉強,計画,問題集,単語帳,暗記,ielts,toefl,sat,数学,模試,復習",
    promo="2分であなただけの学習プラン。適応型の演習、ミスの復習、わかるまで説明するAI家庭教師。",
    short="適応型の試験対策:毎日のプラン、演習、ミス復習、AI家庭教師。",
    intro="Examlyは試験対策を、毎日の短くわかりやすいプランに変えます。試験を選び、5問の診断テストを受けるだけで、学習に合わせて変わるあなた専用の1週間プランが完成します。",
    feats=[
        "診断結果・習熟度・最近のミスから作る毎日の学習プラン",
        "共通テスト、IELTS、TOEFL、SATなど20以上の試験に対応した本番形式の適応型演習",
        "Error DNA:失点につながるパターンを見つけて克服",
        "ステップごとに、必要ならもっとやさしく説明し、写真から問題を解くAI家庭教師",
        "ノートやPDFを要約とクイズに変換",
        "間隔反復の単語カード、時間制限付き模試、集中セッション",
        "ホーム画面ウィジェット:連続記録と、アプリを開かずに答えられる今日の1問",
    ],
    subnote="Examlyは無料で始められます。Premiumでは、無制限のパーソナル演習、高度なAI家庭教師、音声チューター、無制限の学習資料が使えます。オプションのクレジットパックはAIによる画像・動画解説にのみ使用します。サブスクリプションは、期間終了の24時間前までに解約しない限り自動更新されます。ストアのアカウント設定から管理できます。",
    legal="利用規約", privacy="プライバシー",
    notes="Examlyへようこそ!パーソナル学習プラン、適応型演習、AI家庭教師、ウィジェット、20言語に対応。",
)

L["ko"] = dict(
    name="Examly: AI 학습 플래너",
    sub="AI 과외 선생님과 시험 준비",
    kw="수능,모의고사,시험,공부,계획,문제,단어장,암기,ielts,toefl,sat,수학,복습,과외,인강",
    promo="2분 만에 나만의 학습 계획: 맞춤형 문제 풀이, 오답 복습, 이해될 때까지 설명하는 AI 선생님.",
    short="맞춤형 시험 준비: 매일 계획, 문제 풀이, 오답 복습, AI 선생님.",
    intro="Examly는 시험 준비를 매일의 짧고 명확한 계획으로 바꿔 줍니다. 시험을 고르고 5문항 진단 테스트를 풀면, 실력에 맞춰 바뀌는 나만의 한 주 계획이 완성됩니다.",
    feats=[
        "진단 결과, 숙련도, 최근 오답을 바탕으로 한 매일의 맞춤 계획",
        "수능, IELTS, TOEFL, SAT 등 20개 이상 시험의 실전형 맞춤 문제",
        "Error DNA: 점수를 깎는 패턴을 찾아 고치기",
        "단계별로, 필요하면 더 쉽게 설명하고 사진으로 문제를 풀어 주는 AI 선생님",
        "필기와 PDF를 요약과 퀴즈로 변환",
        "간격 반복 단어 카드, 시간 제한 모의고사, 집중 세션",
        "홈 화면 위젯: 연속 학습 기록과 앱을 열지 않고 푸는 오늘의 문제",
    ],
    subnote="Examly는 무료로 시작할 수 있습니다. Premium에서는 무제한 맞춤 연습, 고급 AI 선생님, 음성 튜터, 무제한 학습 자료를 이용할 수 있습니다. 선택 사항인 크레딧 팩은 AI 이미지·영상 설명에만 사용됩니다. 구독은 기간 종료 최소 24시간 전에 해지하지 않으면 자동으로 갱신되며, 스토어 계정 설정에서 관리할 수 있습니다.",
    legal="이용약관", privacy="개인정보 처리방침",
    notes="Examly에 오신 것을 환영합니다! 맞춤 학습 계획, 적응형 문제, AI 선생님, 위젯, 20개 언어 지원.",
)

L["zh-Hans"] = dict(
    name="Examly:AI 学习规划",
    sub="AI 导师助你备考",
    kw="考试,备考,刷题,错题本,单词,记忆卡,学习计划,雅思,托福,ielts,toefl,sat,数学,模考,复习",
    promo="2 分钟生成你的专属备考计划:自适应练习、错题复盘,还有讲到你懂为止的 AI 导师。",
    short="自适应备考:每日计划、练习、错题复盘和 AI 导师。",
    intro="Examly 把备考变成每天简短清晰的计划。选择你的考试,完成 5 道题的诊断测试,就能得到一份随学习进度调整的专属学习周计划。",
    feats=[
        "根据诊断结果、掌握度和近期错题生成的每日个人计划",
        "覆盖雅思、托福、SAT 等 20 多种考试的真题风格自适应练习",
        "Error DNA:找出让你丢分的规律并逐一攻克",
        "AI 导师逐步讲解,需要时讲得更简单,还能拍照解题",
        "把笔记和 PDF 变成摘要和小测验",
        "间隔复习记忆卡、限时模考和专注时段",
        "桌面小组件:连续学习记录,以及无需打开应用就能作答的每日一题",
    ],
    subnote="Examly 可免费开始使用。Premium 解锁无限个性化练习、高级 AI 导师、语音导师和无限学习资料。可选的点数包仅用于 AI 图片和视频讲解。订阅会自动续订,除非在当前周期结束前至少 24 小时取消;可在商店账户设置中管理。",
    legal="使用条款", privacy="隐私政策",
    notes="欢迎使用 Examly!专属学习计划、自适应练习、AI 导师、桌面小组件,支持 20 种语言。",
)

L["zh-Hant"] = dict(
    name="Examly:AI 讀書計畫",
    sub="AI 家教陪你準備考試",
    kw="考試,準備,題庫,錯題,單字,記憶卡,讀書計畫,雅思,托福,ielts,toefl,sat,數學,模擬考,複習",
    promo="2 分鐘產生你的專屬讀書計畫:自適應練習、錯題檢討,還有講到你懂為止的 AI 家教。",
    short="自適應備考:每日計畫、練習、錯題檢討和 AI 家教。",
    intro="Examly 把準備考試變成每天簡短清楚的計畫。選擇你的考試,完成 5 題診斷測驗,就能得到一份會隨學習進度調整的專屬讀書週計畫。",
    feats=[
        "依照診斷結果、熟練度和近期錯題產生的每日個人計畫",
        "涵蓋雅思、托福、SAT 等 20 多種考試的考試風格自適應練習",
        "Error DNA:找出讓你失分的模式並逐一克服",
        "AI 家教逐步講解,需要時講得更簡單,還能拍照解題",
        "把筆記和 PDF 變成摘要和小測驗",
        "間隔複習記憶卡、限時模擬考和專注時段",
        "主畫面小工具:連續學習紀錄,以及不用打開 App 就能作答的每日一題",
    ],
    subnote="Examly 可以免費開始使用。Premium 解鎖無限個人化練習、進階 AI 家教、語音家教和無限學習資料。選購的點數包僅用於 AI 圖片和影片講解。訂閱會自動續訂,除非在目前週期結束前至少 24 小時取消;可在商店帳號設定中管理。",
    legal="使用條款", privacy="隱私權政策",
    notes="歡迎使用 Examly!專屬讀書計畫、自適應練習、AI 家教、主畫面小工具,支援 20 種語言。",
)


def description(d):
    bullets = "\n".join(f"• {f}" for f in d["feats"])
    return (f"{d['intro']}\n\n{bullets}\n\n{d['subnote']}\n\n"
            f"{d['legal']}: {TERMS_URL}\n{d['privacy']}: {PRIVACY_URL}\n")


def write(path, text, field):
    limit = LIMITS.get(field)
    if limit and len(text.strip()) > limit:
        raise SystemExit(f"{path}: {field} is {len(text.strip())} chars (limit {limit})")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.strip() + "\n")


def main():
    missing = set(LOCALES) - set(L)
    if missing:
        sys.exit(f"missing languages: {sorted(missing)}")
    for code, (asc, play) in LOCALES.items():
        d = L[code]
        ios = ROOT / "ios" / "metadata" / asc
        write(ios / "name.txt", d["name"], "name")
        write(ios / "subtitle.txt", d["sub"], "subtitle")
        write(ios / "keywords.txt", d["kw"], "keywords")
        write(ios / "promotional_text.txt", d["promo"], "promotional_text")
        write(ios / "description.txt", description(d), "description")
        # No release_notes.txt: App Store Connect rejects "What's New" on a first version.
        write(ios / "privacy_url.txt", PRIVACY_URL, "privacy_url")
        write(ios / "support_url.txt", SUPPORT_URL, "support_url")
        write(ios / "marketing_url.txt", MARKETING_URL, "marketing_url")

        play_dir = ROOT / "android" / "metadata" / "android" / play
        write(play_dir / "title.txt", d["name"], "title")
        write(play_dir / "short_description.txt", d["short"], "short_description")
        write(play_dir / "full_description.txt", description(d), "full_description")
        write(play_dir / "changelogs" / "1.txt", d["notes"], "changelog")
    print(f"wrote {len(LOCALES)} App Store + {len(LOCALES)} Google Play listings")


if __name__ == "__main__":
    main()

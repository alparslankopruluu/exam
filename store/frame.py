"""Frames raw screenshots with a localized headline for the stores.

Drawing is done by frame.swift with CoreText, so every script (Arabic,
Devanagari, CJK) is shaped and wrapped correctly.

  store/screenshots/raw/{ios,android}/<lang>/<n>_<screen>.png
    -> store/ios/screenshots/<asc-locale>/<n>_<screen>.png      (1320x2868)
    -> store/android/metadata/android/<play-locale>/images/phoneScreenshots/<n>.png (1080x1920)

Usage: python3 store/frame.py [lang ...]
"""
import json
import pathlib
import subprocess
import sys
import tempfile

from listing import LOCALES

ROOT = pathlib.Path(__file__).resolve().parent
SCREENS = ["today", "session", "practice", "tutor"]

CAPTIONS = {
    "en": ["Your study plan, every day", "Practice that adapts to you", "Built around your exam", "An AI tutor that explains until it clicks"],
    "tr": ["Her gün kişisel çalışma planın", "Sana uyum sağlayan sorular", "Sınavına göre hazırlandı", "Anlayana kadar anlatan AI öğretmen"],
    "de": ["Dein Lernplan für jeden Tag", "Übungen, die sich anpassen", "Passend zu deiner Prüfung", "Ein KI-Tutor, der erklärt, bis es klick macht"],
    "fr": ["Ton plan de révision, chaque jour", "Des exercices qui s’adaptent à toi", "Pensé pour ton examen", "Un tuteur IA qui explique jusqu’à ce que tu comprennes"],
    "es": ["Tu plan de estudio, cada día", "Práctica que se adapta a ti", "Hecho para tu examen", "Un tutor IA que explica hasta que lo entiendes"],
    "it": ["Il tuo piano di studio, ogni giorno", "Esercizi che si adattano a te", "Pensato per il tuo esame", "Un tutor IA che spiega finché non è chiaro"],
    "pt": ["Seu plano de estudo, todo dia", "Questões que se adaptam a você", "Feito para a sua prova", "Um tutor de IA que explica até você entender"],
    "pt-PT": ["O teu plano de estudo, todos os dias", "Prática que se adapta a ti", "Feito para o teu exame", "Um tutor de IA que explica até perceberes"],
    "nl": ["Elke dag je studieplan", "Oefenen dat zich aan jou aanpast", "Gemaakt voor jouw examen", "Een AI-tutor die uitlegt tot het klikt"],
    "sv": ["Din pluggplan, varje dag", "Övningar som anpassas efter dig", "Byggd för ditt prov", "En AI-handledare som förklarar tills det sitter"],
    "nb": ["Studieplanen din, hver dag", "Øving som tilpasses deg", "Laget for eksamenen din", "En KI-veileder som forklarer til det sitter"],
    "pl": ["Twój plan nauki na każdy dzień", "Ćwiczenia dopasowane do Ciebie", "Stworzone pod Twój egzamin", "Tutor AI, który tłumaczy, aż zrozumiesz"],
    "ru": ["Ваш учебный план на каждый день", "Практика, которая подстраивается", "Под ваш экзамен", "ИИ-репетитор объясняет, пока не станет ясно"],
    "ar": ["خطتك الدراسية كل يوم", "تدريب يتكيّف معك", "مصمم لاختبارك", "معلم ذكي يشرح حتى تفهم"],
    "hi": ["हर दिन आपका स्टडी प्लान", "आपके हिसाब से ढलती प्रैक्टिस", "आपकी परीक्षा के लिए बना", "AI ट्यूटर जो समझ आने तक समझाए"],
    "id": ["Rencana belajarmu setiap hari", "Latihan yang menyesuaikan dirimu", "Dibuat untuk ujianmu", "Tutor AI yang menjelaskan sampai paham"],
    "ja": ["毎日のあなた専用プラン", "あなたに合わせて変わる演習", "あなたの試験に合わせて", "わかるまで説明する\nAI家庭教師"],
    "ko": ["매일 나만의 학습 계획", "나에게 맞춰지는 문제 풀이", "내 시험에 맞춘 구성", "이해될 때까지 설명하는 AI 선생님"],
    "zh-Hans": ["每天的专属学习计划", "随你调整的练习", "为你的考试量身打造", "讲到你懂为止的 AI 导师"],
    "zh-Hant": ["每天的專屬讀書計畫", "隨你調整的練習", "為你的考試量身打造", "講到你懂為止的 AI 家教"],
}

TARGETS = {
    # platform: (canvas width, height, output path builder)
    "ios": (1320, 2868, lambda lang, n, screen: ROOT / "ios" / "screenshots" / LOCALES[lang][0] / f"{n}_{screen}.png"),
    "android": (1080, 1920, lambda lang, n, screen: ROOT / "android" / "metadata" / "android" / LOCALES[lang][1] / "images" / "phoneScreenshots" / f"{n}.png"),
}

def job(lang, platform, n, screen, raw):
    w, h, out_for = TARGETS[platform]
    return {"raw": str(raw), "out": str(out_for(lang, n, screen)), "width": w, "height": h,
            "caption": CAPTIONS[lang][n - 1], "rtl": lang == "ar"}


def main():
    langs = sys.argv[1:] or list(LOCALES)
    jobs = [
        job(lang, platform, n, screen, raw)
        for lang in langs
        for platform in TARGETS
        for n, screen in enumerate(SCREENS, start=1)
        if (raw := ROOT / "screenshots" / "raw" / platform / lang / f"{n}_{screen}.png").exists()
    ]
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(jobs, f)
    subprocess.run(["swift", str(ROOT / "frame.swift"), f.name], check=True)
    pathlib.Path(f.name).unlink()


if __name__ == "__main__":
    main()

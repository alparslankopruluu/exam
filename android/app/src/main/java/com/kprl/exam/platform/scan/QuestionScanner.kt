package com.kprl.exam.platform.scan

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

class QuestionScanner {
    fun recognize(
        bitmap: Bitmap,
        languageCode: String,
        onResult: (Result<String>) -> Unit
    ) {
        val recognizer = recognizer(languageCode)
        val image = InputImage.fromBitmap(bitmap, 0)

        recognizer.process(image)
            .addOnSuccessListener { text -> onResult(Result.success(text.text.trim())) }
            .addOnFailureListener { error -> onResult(Result.failure(error)) }
            .addOnCompleteListener { recognizer.close() }
    }

    private fun recognizer(languageCode: String): TextRecognizer {
        val code = languageCode.lowercase().substringBefore("-")
        return when (code) {
            "zh" -> TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
            "hi", "mr", "ne" -> TextRecognition.getClient(DevanagariTextRecognizerOptions.Builder().build())
            "ja" -> TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build())
            "ko" -> TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
            else -> TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        }
    }
}

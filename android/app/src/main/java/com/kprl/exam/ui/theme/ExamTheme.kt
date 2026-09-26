package com.kprl.exam.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

object ExamColors {
    val Background = Color(0xFFF7F9FC)
    val Surface = Color.White
    val TextPrimary = Color(0xFF0F172A)
    val TextSecondary = Color(0xFF64748B)
    val Primary = Color(0xFF3B6CF6)
    val Indigo = Color(0xFF5C5CF6)
    val Mint = Color(0xFF2CCB8C)
    val Amber = Color(0xFFF5A524)
    val Coral = Color(0xFFF26D6D)
    val Purple = Color(0xFF8B5CF6)
    val Border = Color(0xFFE6EAF2)
    val SoftBlue = Color(0xFFEAF1FF)
    val SoftMint = Color(0xFFE9F9F2)
    val SoftPurple = Color(0xFFF2EEFF)
}

private val LightScheme = lightColorScheme(
    primary = ExamColors.Primary,
    secondary = ExamColors.Indigo,
    background = ExamColors.Background,
    surface = ExamColors.Surface,
    onBackground = ExamColors.TextPrimary,
    onSurface = ExamColors.TextPrimary,
    outline = ExamColors.Border,
    error = ExamColors.Coral
)

@Composable
fun ExamTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = LightScheme, content = content)
}

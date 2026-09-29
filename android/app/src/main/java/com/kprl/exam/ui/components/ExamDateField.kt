package com.kprl.exam.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.localization.LocalizedCopy
import com.kprl.exam.ui.theme.ExamColors
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/** Optional exam date picker; null means "I don't know yet". */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExamDateField(
    title: String,
    copy: LocalizedCopy,
    languageCode: String,
    date: LocalDate?,
    onChange: (LocalDate?) -> Unit
) {
    var picking by remember { mutableStateOf(false) }
    val formatter = remember(languageCode) {
        DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(Locale.forLanguageTag(languageCode))
    }

    Surface(
        color = ExamColors.Surface,
        shape = RoundedCornerShape(20.dp),
        border = BorderStroke(1.dp, ExamColors.Border),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(title, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = { picking = true }) {
                    Text(date?.format(formatter) ?: copy.text("exam_date_add"), color = ExamColors.Primary, fontWeight = FontWeight.SemiBold)
                }
                if (date != null) {
                    TextButton(onClick = { onChange(null) }) {
                        Text(copy.text("exam_date_unknown"), color = ExamColors.TextSecondary, fontSize = 13.sp)
                    }
                }
            }
        }
    }

    if (picking) {
        val today = LocalDate.now()
        val state = rememberDatePickerState(
            initialSelectedDateMillis = (date ?: today.plusMonths(3)).atStartOfDay().toInstant(ZoneOffset.UTC).toEpochMilli(),
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long) =
                    !Instant.ofEpochMilli(utcTimeMillis).atZone(ZoneOffset.UTC).toLocalDate().isBefore(today)
            }
        )
        DatePickerDialog(
            onDismissRequest = { picking = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let {
                        onChange(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate())
                    }
                    picking = false
                }) { Text(copy.text("done")) }
            },
            dismissButton = { TextButton(onClick = { picking = false }) { Text(copy.text("cancel")) } }
        ) {
            DatePicker(state = state)
        }
    }
}

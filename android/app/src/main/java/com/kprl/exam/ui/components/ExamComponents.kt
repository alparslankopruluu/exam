package com.kprl.exam.ui.components

import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.foundation.border
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.graphics.Brush
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.ui.theme.ExamColors

@Composable
fun ExamPrimaryButton(text: String, enabled: Boolean = true, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth().height(56.dp),
        shape = RoundedCornerShape(18.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = ExamColors.Primary,
            contentColor = Color.White,
            disabledContainerColor = ExamColors.Border,
            disabledContentColor = ExamColors.TextSecondary
        ),
        elevation = ButtonDefaults.buttonElevation(0.dp, 0.dp)
    ) {
        Text(text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
fun ExamSelectionCard(
    title: String,
    subtitle: String,
    icon: ImageVector,
    accent: Color,
    selected: Boolean,
    onClick: () -> Unit
) {
    val border = animateColorAsState(if (selected) ExamColors.Primary else ExamColors.Border, label = "border")
    Surface(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        shape = RoundedCornerShape(18.dp),
        color = ExamColors.Surface,
        border = BorderStroke(if (selected) 1.5.dp else 1.dp, border.value),
        shadowElevation = if (selected) 3.dp else 0.dp
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(46.dp).background(accent.copy(alpha = .12f), RoundedCornerShape(14.dp)),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, null, tint = accent, modifier = Modifier.size(23.dp))
            }
            Spacer(Modifier.width(13.dp))
            Column(Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                Text(subtitle, color = ExamColors.TextSecondary, fontSize = 12.sp)
            }
            Text(
                if (selected) "✓" else "",
                color = Color.White,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .size(22.dp)
                    .background(if (selected) ExamColors.Primary else ExamColors.Background, RoundedCornerShape(50))
                    .wrapContentSize(Alignment.Center)
            )
        }
    }
}

/**
 * Rounded-square icon badge with a soft accent gradient, used wherever an
 * icon leads a card or row so icons read as one consistent, premium set.
 */
@Composable
fun ExamIconBadge(icon: ImageVector, accent: Color, size: Dp = 34.dp) {
    val shape = RoundedCornerShape(size * 0.32f)
    Box(
        modifier = Modifier
            .size(size)
            .clip(shape)
            .background(Brush.linearGradient(listOf(accent.copy(alpha = .22f), accent.copy(alpha = .08f))))
            .border(1.dp, accent.copy(alpha = .18f), shape),
        contentAlignment = Alignment.Center
    ) {
        Icon(icon, null, tint = accent, modifier = Modifier.size(size * 0.52f))
    }
}

@Composable
fun ExamStatPill(value: String, label: String, icon: ImageVector, accent: Color, modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier,
        color = ExamColors.Surface,
        shape = RoundedCornerShape(20.dp),
        border = BorderStroke(1.dp, ExamColors.Border)
    ) {
        Column(Modifier.padding(12.dp)) {
            ExamIconBadge(icon, accent, size = 32.dp)
            Spacer(Modifier.height(8.dp))
            Text(value, fontSize = 20.sp, fontWeight = FontWeight.Bold, maxLines = 1)
            Spacer(Modifier.height(2.dp))
            // Always reserve two lines so every pill in a row has the same height.
            Text(
                label,
                fontSize = 11.sp,
                lineHeight = 14.sp,
                fontWeight = FontWeight.Medium,
                color = ExamColors.TextSecondary,
                minLines = 2,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

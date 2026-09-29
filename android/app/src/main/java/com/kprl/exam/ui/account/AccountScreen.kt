package com.kprl.exam.ui.account

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kprl.exam.localization.LocalizedCopy
import com.kprl.exam.platform.AppServices
import com.kprl.exam.platform.account.AuthCancelledException
import com.kprl.exam.platform.account.AuthService
import com.kprl.exam.ui.components.ExamPrimaryButton
import com.kprl.exam.ui.theme.ExamColors
import kotlinx.coroutines.launch

/**
 * Lets an anonymous learner save progress with Google or email,
 * and shows the linked account once upgraded.
 */
@Composable
fun AccountScreen(copy: LocalizedCopy, onClose: () -> Unit) {
    val context = LocalContext.current
    val activity = remember(context) { context.findActivity() }
    val account by AuthService.account.collectAsState()
    val scope = rememberCoroutineScope()

    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var createAccount by remember { mutableStateOf(true) }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var isError by remember { mutableStateOf(false) }

    fun run(success: String? = null, work: suspend () -> Unit) {
        busy = true
        message = null
        scope.launch {
            try {
                work()
                isError = false
                message = success
                if (success == null) AppServices.analytics.event("account_linked")
            } catch (_: AuthCancelledException) {
                // User dismissed the provider sheet; nothing to report.
            } catch (error: Exception) {
                isError = true
                message = error.localizedMessage
            } finally {
                busy = false
            }
        }
    }

    Column(
        Modifier.fillMaxSize().background(ExamColors.Background)
            .statusBarsPadding().navigationBarsPadding()
            .verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterEnd) {
            IconButton(
                onClick = onClose,
                modifier = Modifier.size(36.dp).background(ExamColors.Surface, CircleShape)
            ) {
                Icon(Icons.Rounded.Close, null, tint = ExamColors.TextSecondary)
            }
        }

        if (account.isSignedIn && !account.isAnonymous) {
            Text(copy.text("account_saved_title"), fontSize = 28.sp, fontWeight = FontWeight.Bold, color = ExamColors.TextPrimary)
            Text(account.email ?: copy.text("account_saved_subtitle"), fontSize = 15.sp, color = ExamColors.TextSecondary)
            ExamPrimaryButton(copy.text("account_sign_out"), enabled = !busy && activity != null) {
                run { AuthService.signOut(activity!!) }
            }
        } else {
            Text(copy.text("account_title"), fontSize = 28.sp, fontWeight = FontWeight.Bold, color = ExamColors.TextPrimary)
            Text(copy.text("account_subtitle"), fontSize = 15.sp, color = ExamColors.TextSecondary)

            Surface(
                modifier = Modifier.fillMaxWidth().height(54.dp),
                onClick = { activity?.let { run { AuthService.continueWithGoogle(it) } } },
                enabled = !busy && activity != null,
                color = ExamColors.Surface,
                shape = RoundedCornerShape(18.dp),
                border = BorderStroke(1.dp, ExamColors.Border)
            ) {
                Row(horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                    Text("G", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = ExamColors.Primary)
                    Spacer(Modifier.width(10.dp))
                    Text(copy.text("account_continue_google"), fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = ExamColors.TextPrimary)
                }
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                HorizontalDivider(Modifier.weight(1f), color = ExamColors.Border)
                Text(copy.text("account_or_email"), Modifier.padding(horizontal = 8.dp), fontSize = 12.sp, color = ExamColors.TextSecondary)
                HorizontalDivider(Modifier.weight(1f), color = ExamColors.Border)
            }

            OutlinedTextField(
                value = email,
                onValueChange = { email = it.trim() },
                label = { Text(copy.text("account_email")) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth()
            )
            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text(copy.text("account_password")) },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth()
            )

            ExamPrimaryButton(
                copy.text(if (createAccount) "account_create" else "account_sign_in"),
                enabled = !busy && "@" in email && password.length >= 6
            ) {
                run { AuthService.continueWithEmail(email, password, createAccount) }
            }

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                TextButton(onClick = { createAccount = !createAccount; message = null }) {
                    Text(copy.text(if (createAccount) "account_have_account" else "account_need_account"), color = ExamColors.Primary)
                }
                if (!createAccount) {
                    TextButton(
                        onClick = { run(copy.text("account_reset_sent")) { AuthService.sendPasswordReset(email) } },
                        enabled = "@" in email
                    ) {
                        Text(copy.text("account_forgot_password"), color = ExamColors.Primary)
                    }
                }
            }
        }

        message?.let {
            Text(it, fontSize = 13.sp, color = if (isError) ExamColors.Coral else ExamColors.Mint)
        }
    }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

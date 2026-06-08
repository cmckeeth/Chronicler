package app.chronicler

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

@Composable
fun LoginScreen(auth: AuthStore) {
    var mode by remember { mutableStateOf("login") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Box(Modifier.fillMaxSize().background(Theme.bg), contentAlignment = Alignment.Center) {
        Column(
            Modifier.padding(28.dp).fillMaxWidth()
                .background(Theme.surface, RoundedCornerShape(6.dp))
                .padding(horizontal = 28.dp, vertical = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            Text("Chronicler", color = Theme.brass, fontSize = 34.sp, fontWeight = FontWeight.Bold,
                fontFamily = Theme.display,
                style = androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris))
            Text("Your audiobook library", color = Theme.parchmentDim, fontSize = 14.sp,
                fontFamily = Theme.serif)

            Row(Modifier.fillMaxWidth().background(Theme.surface2, RoundedCornerShape(4.dp)).padding(4.dp)) {
                tab("Sign In", mode == "login", Modifier.weight(1f)) { mode = "login" }
                tab("Register", mode == "register", Modifier.weight(1f)) { mode = "register" }
            }

            field("Email", email, KeyboardType.Email, false) { email = it }
            field("Password", password, KeyboardType.Password, true) { password = it }

            error?.let { Text(it, color = Theme.rust, fontSize = 13.sp) }

            Button(
                onClick = {
                    error = null; busy = true
                    scope.launch {
                        val token = if (mode == "login") auth.api.login(email, password)
                                    else auth.api.register(email, password)
                        busy = false
                        if (token == null) {
                            error = if (mode == "login") "Invalid email or password." else "Registration failed."
                        } else auth.setToken(token, email)
                    }
                },
                enabled = !busy,
                colors = ButtonDefaults.buttonColors(containerColor = Theme.brass, contentColor = Theme.ink),
                shape = RoundedCornerShape(4.dp),
                modifier = Modifier.fillMaxWidth()
            ) { Text(if (mode == "login") "Sign In" else "Create Account") }
        }
    }
}

@Composable
private fun tab(label: String, active: Boolean, modifier: Modifier, onClick: () -> Unit) {
    TextButton(onClick = onClick, modifier = modifier,
        colors = ButtonDefaults.textButtonColors(
            containerColor = if (active) Theme.brass else androidx.compose.ui.graphics.Color.Transparent,
            contentColor = if (active) Theme.ink else Theme.parchmentMid)) {
        Text(label)
    }
}

@Composable
private fun field(placeholder: String, value: String, type: KeyboardType, secure: Boolean,
                  onChange: (String) -> Unit) {
    OutlinedTextField(
        value = value, onValueChange = onChange,
        placeholder = { Text(placeholder, color = Theme.parchmentDim) },
        singleLine = true,
        visualTransformation = if (secure) PasswordVisualTransformation() else androidx.compose.ui.text.input.VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = type),
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = Theme.parchment, unfocusedTextColor = Theme.parchment,
            focusedBorderColor = Theme.borderBrass, unfocusedBorderColor = Theme.border,
            focusedContainerColor = Theme.surface2, unfocusedContainerColor = Theme.surface2),
        modifier = Modifier.fillMaxWidth()
    )
}

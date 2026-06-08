package app.chronicler

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController

@Composable
fun LandingScreen(auth: AuthStore, nav: NavController) {
    val context = LocalContext.current
    androidx.compose.runtime.LaunchedEffect(Unit) { StartupSound.play(context) }

    Box(Modifier.fillMaxSize().background(Theme.bg)) {
        // Gear corners
        Column(Modifier.fillMaxSize().padding(20.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                gear(); gear()
            }
            Spacer(Modifier.weight(1f))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                gear(); gear()
            }
        }

        Column(
            Modifier.fillMaxSize().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text("Chronicler", color = Theme.brass, fontSize = 40.sp, fontWeight = FontWeight.Bold)
            Text("Your Audiobook Library", color = Theme.parchmentDim, fontSize = 15.sp)
            Spacer(Modifier.height(8.dp))
            Text("⚙ ───────── ⚙", color = Theme.borderBrass, fontSize = 14.sp)
            Spacer(Modifier.height(40.dp))

            Column(
                Modifier
                    .clickable { nav.navigate("archive") }
                    .background(Theme.surface, RoundedCornerShape(6.dp))
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Image(painterResource(R.drawable.logo), contentDescription = null,
                    modifier = Modifier.size(90.dp))
                Text("Enter the Archive", color = Theme.brassPale, fontSize = 20.sp)
                Text("Browse your collection", color = Theme.parchmentDim, fontSize = 13.sp)
            }
        }

        TextButton(onClick = { auth.clear() },
            modifier = Modifier.align(Alignment.TopEnd).padding(8.dp).alpha(0.5f)) {
            Text("Sign Out", color = Theme.parchmentDim, fontSize = 11.sp)
        }
    }
}

@Composable
private fun gear() {
    Text("⚙", color = Theme.border, fontSize = 26.sp, modifier = Modifier.alpha(0.6f))
}

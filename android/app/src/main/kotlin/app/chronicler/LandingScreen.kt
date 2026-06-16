package app.chronicler

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
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

    Box(Modifier.fillMaxSize()) {   // transparent: the app-wide electric backdrop shows through
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
            Text("Chronicler", color = Theme.brass, fontSize = 38.sp, fontWeight = FontWeight.Bold,
                fontFamily = Theme.display, maxLines = 1, softWrap = false,
                style = androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris))
            Text("Your Audiobook Library", color = Theme.parchmentDim, fontSize = 15.sp,
                fontFamily = Theme.serif)
            Spacer(Modifier.height(8.dp))
            Text("⚙ ───────── ⚙", color = Theme.borderBrass, fontSize = 14.sp)
            Spacer(Modifier.height(40.dp))

            Column(
                Modifier
                    .clickable { nav.navigate("archive") }
                    .electricPanel(Theme.surface, corner = 6.dp, alpha = 0.8f, elevation = 20.dp)
                    .padding(28.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Image(painterResource(R.drawable.logo), contentDescription = null,
                    modifier = Modifier.size(190.dp))
                Text("Enter the Archive", color = Theme.brassPale, fontSize = 20.sp,
                    fontFamily = Theme.serif,
                    style = androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris))
            }
        }

        TextButton(onClick = { auth.clear() },
            modifier = Modifier.align(Alignment.TopEnd).padding(8.dp).alpha(0.5f)) {
            Text("Sign Out", color = Theme.parchmentDim, fontSize = 11.sp)
        }

        UpdateBanner(auth.api, modifier = Modifier.align(Alignment.BottomCenter).padding(12.dp))
    }
}

@Composable
private fun gear() {
    Text("⚙", color = Theme.border, fontSize = 26.sp, modifier = Modifier.alpha(0.6f))
}

// Status bar + self-update prompt, ported from the Blazor UpdateBanner.
// Shared by the landing and archive pages.
@Composable
fun UpdateBanner(api: ApiClient, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val current = remember {
        runCatching {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName
        }.getOrNull() ?: "?"
    }
    var connected by remember { mutableStateOf(false) }
    var latest by remember { mutableStateOf<String?>(null) }
    val latestVer = latest
    val updateAvailable = latestVer != null && latestVer != "0.0.0" && isNewer(latestVer, current)

    LaunchedEffect(Unit) {
        while (true) {
            val v = api.getLatestVersion()
            connected = v != null
            if (v != null) latest = v
            kotlinx.coroutines.delay(10_000)
        }
    }

    Row(modifier, verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("●", color = if (connected) Theme.verdigris else Theme.rust, fontSize = 10.sp)
        Text("v$current", color = Theme.parchmentDim, fontSize = 12.sp)
        if (updateAvailable) {
            Text("⚡ v$latestVer available — tap to install",
                color = Theme.brassPale, fontSize = 12.sp, fontWeight = FontWeight.Bold,
                style = androidx.compose.ui.text.TextStyle(shadow = Theme.glowVerdigris),
                modifier = Modifier.clickable {
                    val url = "${ApiClient.BASE_URL}/api/update/apk/Chronicler-v$latestVer.apk"
                    context.startActivity(
                        android.content.Intent(android.content.Intent.ACTION_VIEW,
                            android.net.Uri.parse(url)))
                })
        } else {
            Text(if (connected) "Connected" else "Server unreachable",
                color = Theme.parchmentDim, fontSize = 12.sp)
        }
    }
}

// Compare dotted versions: is [a] strictly newer than [b]?
private fun isNewer(a: String, b: String): Boolean {
    val pa = a.split(".").map { it.toIntOrNull() ?: 0 }
    val pb = b.split(".").map { it.toIntOrNull() ?: 0 }
    for (i in 0 until maxOf(pa.size, pb.size)) {
        val x = pa.getOrElse(i) { 0 }; val y = pb.getOrElse(i) { 0 }
        if (x != y) return x > y
    }
    return false
}

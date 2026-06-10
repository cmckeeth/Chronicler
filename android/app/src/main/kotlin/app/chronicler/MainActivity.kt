package app.chronicler

import android.os.Build
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Density
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.navigation.NavType

class MainActivity : androidx.appcompat.app.AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        CrashReporter.install()
        enableEdgeToEdge()
        requestNotificationPermission()
        val auth = AuthStore(applicationContext)
        setContent { App(auth) }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
                android.content.pm.PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 0)
        }
    }
}

@Composable
fun App(auth: AuthStore) {
    MaterialTheme {
        val base = LocalDensity.current
        CompositionLocalProvider(
            // Bump all text ~20% larger app-wide.
            LocalDensity provides Density(base.density, base.fontScale * 1.2f),
            LocalTextStyle provides TextStyle(fontFamily = Theme.body, color = Theme.parchment)
        ) {
        Surface(modifier = Modifier.fillMaxSize().background(Theme.bg), color = Theme.bg) {
            // Inset content below the status bar / camera cutout and above the nav bar.
            Box(Modifier.fillMaxSize().systemBarsPadding()) {
                if (!auth.isAuthenticated) {
                    LoginScreen(auth)
                } else {
                    val nav = rememberNavController()
                    NavHost(navController = nav, startDestination = "landing") {
                        composable("landing") { LandingScreen(auth, nav) }
                        composable("archive") { ArchiveScreen(auth, nav) }
                        composable(
                            "book/{id}",
                            arguments = listOf(navArgument("id") { type = NavType.IntType })
                        ) { entry ->
                            BookPlayerScreen(
                                auth, nav,
                                bookId = entry.arguments?.getInt("id") ?: 0
                            )
                        }
                    }
                }
            }
        }
        }
    }
}

package app.chronicler

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.navigation.NavType

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val auth = AuthStore(applicationContext)
        setContent { App(auth) }
    }
}

@Composable
fun App(auth: AuthStore) {
    MaterialTheme {
        CompositionLocalProvider(
            LocalTextStyle provides TextStyle(fontFamily = Theme.body, color = Theme.parchment)
        ) {
        Surface(modifier = Modifier.fillMaxSize().background(Theme.bg), color = Theme.bg) {
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

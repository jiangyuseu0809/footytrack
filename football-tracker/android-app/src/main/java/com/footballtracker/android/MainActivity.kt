package com.footballtracker.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.footballtracker.android.data.db.SessionEntity
import com.footballtracker.android.data.model.UserProfile
import com.footballtracker.android.sync.WatchController
import com.footballtracker.android.ui.screens.*
import com.footballtracker.android.ui.theme.*
import com.footballtracker.core.model.SessionStats
import com.footballtracker.core.model.TrackPoint
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    private val appContainer by lazy {
        (application as FootballTrackerApp).appContainer
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT)
        )
        super.onCreate(savedInstanceState)

        setContent {
            FootballTrackerTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = DarkBg
                ) {
                    AppRoot()
                }
            }
        }
    }

    @Composable
    private fun AppRoot() {
        val authRepo = appContainer.authRepository
        val userRepo = appContainer.userRepository
        val sessionRepo = appContainer.sessionRepo
        val cloudSync = appContainer.cloudSync
        val weChatHelper = appContainer.weChatAuthHelper
        val watchController = appContainer.watchController

        val currentUser by authRepo.currentUser.collectAsState()
        val navController = rememberNavController()

        // Manage watch listener lifecycle
        DisposableEffect(Unit) {
            watchController.startListening()
            onDispose { watchController.stopListening() }
        }

        var sessions by remember { mutableStateOf<List<SessionEntity>>(emptyList()) }
        var selectedSession by remember { mutableStateOf<SessionEntity?>(null) }
        var selectedStats by remember { mutableStateOf<SessionStats?>(null) }
        var selectedPoints by remember { mutableStateOf<List<TrackPoint>>(emptyList()) }

        // Load sessions only when logged in; unlogged users see empty home
        LaunchedEffect(currentUser) {
            if (currentUser != null) {
                sessions = sessionRepo.getAllSessions()
                sessionRepo.getSessionDao().assignOwner(currentUser!!.uid)
            } else {
                sessions = emptyList()
            }
        }

        val navBackStackEntry by navController.currentBackStackEntryAsState()
        val currentRoute = navBackStackEntry?.destination?.route

        val bottomNavRoutes = listOf("home", "stats", "community", "profile")
        val showBottomNav = currentRoute in bottomNavRoutes

        Scaffold(
            containerColor = DarkBg,
            contentWindowInsets = WindowInsets.systemBars,
            bottomBar = {
                if (showBottomNav) {
                    NavigationBar(
                        containerColor = CardBg,
                        contentColor = TextPrimary,
                        tonalElevation = 0.dp
                    ) {
                        BottomNavItem.entries.forEach { item ->
                            val selected = currentRoute == item.route
                            NavigationBarItem(
                                selected = selected,
                                onClick = {
                                    if (currentRoute != item.route) {
                                        navController.navigate(item.route) {
                                            popUpTo("home") { saveState = true }
                                            launchSingleTop = true
                                            restoreState = true
                                        }
                                    }
                                },
                                icon = {
                                    Icon(
                                        imageVector = item.icon,
                                        contentDescription = item.label
                                    )
                                },
                                label = {
                                    Text(
                                        text = item.label,
                                        fontSize = MaterialTheme.typography.labelSmall.fontSize
                                    )
                                },
                                colors = NavigationBarItemDefaults.colors(
                                    selectedIconColor = NeonBlue,
                                    selectedTextColor = NeonBlue,
                                    unselectedIconColor = TextSecondary,
                                    unselectedTextColor = TextSecondary,
                                    indicatorColor = NeonBlue.copy(alpha = 0.12f)
                                )
                            )
                        }
                    }
                }
            }
        ) { padding ->
            NavHost(
                navController = navController,
                startDestination = "home",
                modifier = Modifier.padding(padding)
            ) {
                // ── Auth screens ──
                composable("login") {
                    LoginScreen(
                        authRepository = authRepo,
                        onAuthSuccess = { isNewUser ->
                            if (isNewUser) {
                                navController.navigate("onboarding") {
                                    popUpTo("login") { inclusive = true }
                                }
                            } else {
                                navController.navigate("home") {
                                    popUpTo("login") { inclusive = true }
                                }
                            }
                        },
                        onNavigateToRegister = {
                            navController.navigate("register")
                        }
                    )
                }

                composable("register") {
                    RegisterScreen(
                        authRepository = authRepo,
                        onAuthSuccess = { isNewUser ->
                            navController.navigate("onboarding") {
                                popUpTo("login") { inclusive = true }
                            }
                        },
                        onNavigateToLogin = {
                            navController.popBackStack()
                        }
                    )
                }

                composable("phone_auth") {
                    PhoneAuthScreen(
                        authRepository = authRepo,
                        onBack = { navController.popBackStack() },
                        onAuthSuccess = { isNewUser ->
                            if (isNewUser) {
                                navController.navigate("onboarding") {
                                    popUpTo("login") { inclusive = true }
                                }
                            } else {
                                navController.navigate("home") {
                                    popUpTo("login") { inclusive = true }
                                }
                            }
                        }
                    )
                }

                composable("onboarding") {
                    OnboardingScreen { nickname, weightKg, age ->
                        lifecycleScope.launch {
                            val uid = authRepo.currentUser.value?.uid ?: return@launch
                            val phone = authRepo.currentUser.value?.phone
                            val authProvider = when {
                                authRepo.currentUser.value?.username != null -> "password"
                                phone != null -> "phone"
                                else -> "wechat"
                            }
                            val profile = UserProfile(
                                uid = uid,
                                nickname = nickname,
                                weightKg = weightKg,
                                age = age,
                                authProvider = authProvider,
                                phone = phone
                            )
                            try {
                                userRepo.saveProfile(profile)
                            } catch (_: Exception) {
                                // Profile save handled internally; navigate regardless
                            }
                            navController.navigate("home") {
                                popUpTo("onboarding") { inclusive = true }
                            }
                        }
                    }
                }

                // ── Main screens ──
                composable("home") {
                    HomeScreen(
                        sessions = sessions,
                        watchController = watchController,
                        onSessionClick = { sessionId ->
                            lifecycleScope.launch {
                                val result = sessionRepo.getSessionWithStats(sessionId)
                                if (result != null) {
                                    selectedSession = result.first
                                    selectedStats = result.second
                                    selectedPoints = sessionRepo.getTrackPoints(sessionId)
                                    navController.navigate("detail")
                                }
                            }
                        },
                        onNavigateCreateMatch = {
                            navController.navigate("create_match")
                        },
                        onNavigateMatchDetail = { matchId ->
                            navController.navigate("match_detail/$matchId")
                        }
                    )
                }

                composable("detail") {
                    val session = selectedSession
                    val stats = selectedStats
                    if (session != null && stats != null) {
                        SessionDetailScreen(
                            session = session,
                            stats = stats,
                            trackPoints = selectedPoints,
                            onBack = { navController.popBackStack() }
                        )
                    }
                }

                composable("heatmap") {
                    val stats = selectedStats
                    if (stats != null) {
                        HeatmapScreen(
                            stats = stats,
                            onBack = { navController.popBackStack() }
                        )
                    }
                }

                composable("stats") {
                    StatsScreen(
                        sessions = sessions,
                        onBack = { navController.popBackStack() }
                    )
                }

                composable("community") {
                    CommunityScreen()
                }

                composable("profile") {
                    ProfileScreen(
                        sessions = sessions,
                        userRepository = userRepo,
                        authRepository = authRepo,
                        cloudSync = cloudSync,
                        onNavigateTeams = { navController.navigate("team_list") },
                        onNavigateTeamDetail = { teamId -> navController.navigate("team_detail/$teamId") },
                        onLogout = {
                            lifecycleScope.launch {
                                authRepo.signOut()
                                navController.navigate("home") {
                                    popUpTo(0) { inclusive = true }
                                }
                            }
                        }
                    )
                }

                composable("team_list") {
                    TeamListScreen(
                        onNavigateTeamDetail = { teamId -> navController.navigate("team_detail/$teamId") },
                        onBack = { navController.popBackStack() }
                    )
                }

                composable("team_detail/{teamId}") { backStackEntry ->
                    val teamId = backStackEntry.arguments?.getString("teamId") ?: return@composable
                    TeamDetailScreen(
                        teamId = teamId,
                        onBack = { navController.popBackStack() }
                    )
                }

                // ── Match screens ──
                composable("create_match") {
                    CreateMatchScreen(
                        onBack = { navController.popBackStack() },
                        onMatchCreated = { matchId ->
                            navController.popBackStack()
                            navController.navigate("match_detail/$matchId")
                        }
                    )
                }

                composable("match_detail/{matchId}") { backStackEntry ->
                    val matchId = backStackEntry.arguments?.getString("matchId") ?: return@composable
                    MatchDetailScreen(
                        matchId = matchId,
                        currentUid = currentUser?.uid,
                        onBack = { navController.popBackStack() }
                    )
                }
            }
        }
    }
}

private enum class BottomNavItem(val route: String, val label: String, val icon: ImageVector) {
    Home("home", "Home", Icons.Rounded.Home),
    History("stats", "History", Icons.Rounded.History),
    Community("community", "Community", Icons.Rounded.Groups),
    Profile("profile", "Profile", Icons.Rounded.Person)
}

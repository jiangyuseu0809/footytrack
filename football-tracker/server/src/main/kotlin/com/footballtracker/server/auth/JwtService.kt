package com.footballtracker.server.auth

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import com.footballtracker.server.config.JwtConfig
import java.util.*

class JwtService(private val config: JwtConfig) {

    private val algorithm = Algorithm.HMAC256(config.secret)

    fun generateToken(uid: String): String {
        return JWT.create()
            .withIssuer(config.issuer)
            .withAudience(config.audience)
            .withClaim("uid", uid)
            .withExpiresAt(Date(System.currentTimeMillis() + config.expirationDays * 24 * 60 * 60 * 1000))
            .sign(algorithm)
    }
}

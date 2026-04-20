package com.footballtracker.server.routes

import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable

@Serializable
data class PlanResponse(
    val id: String,
    val name: String,
    val price: Double,
    val originalPrice: Double? = null,
    val period: String,
    val discount: Int? = null, // e.g. 80 means 8折
    val popular: Boolean = false
)

@Serializable
data class PricingResponse(
    val plans: List<PlanResponse>,
    val trialDays: Int = 7
)

fun Route.pricingRoutes() {
    get("/pricing") {
        val monthlyBase = System.getenv("PRO_MONTHLY_PRICE")?.toDoubleOrNull() ?: 9.9
        val yearlyBase = System.getenv("PRO_YEARLY_PRICE")?.toDoubleOrNull() ?: 66.0
        val lifetimeBase = System.getenv("PRO_LIFETIME_PRICE")?.toDoubleOrNull() ?: 128.0

        val monthlyDiscount = System.getenv("PRO_MONTHLY_DISCOUNT")?.toIntOrNull()
        val yearlyDiscount = System.getenv("PRO_YEARLY_DISCOUNT")?.toIntOrNull()
        val lifetimeDiscount = System.getenv("PRO_LIFETIME_DISCOUNT")?.toIntOrNull()

        fun applyDiscount(base: Double, discount: Int?): Pair<Double, Double?> {
            if (discount != null && discount in 1..99) {
                val actual = Math.round(base * discount / 100.0 * 10.0) / 10.0
                return actual to base
            }
            return base to null
        }

        val (lifetimePrice, lifetimeOriginal) = applyDiscount(lifetimeBase, lifetimeDiscount)
        val (yearlyPrice, yearlyOriginal) = applyDiscount(yearlyBase, yearlyDiscount)
        val (monthlyPrice, monthlyOriginal) = applyDiscount(monthlyBase, monthlyDiscount)

        val plans = listOf(
            PlanResponse(
                id = "lifetime",
                name = "永久订阅",
                price = lifetimePrice,
                originalPrice = lifetimeOriginal,
                period = "永久",
                discount = lifetimeDiscount,
                popular = true
            ),
            PlanResponse(
                id = "yearly",
                name = "年度订阅",
                price = yearlyPrice,
                originalPrice = yearlyOriginal,
                period = "/年",
                discount = yearlyDiscount,
                popular = false
            ),
            PlanResponse(
                id = "monthly",
                name = "月度订阅",
                price = monthlyPrice,
                originalPrice = monthlyOriginal,
                period = "/月",
                discount = monthlyDiscount,
                popular = false
            )
        )

        call.respond(PricingResponse(plans = plans))
    }
}

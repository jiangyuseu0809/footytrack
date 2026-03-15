package com.footballtracker.android.data.db

import androidx.room.*
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Entity(tableName = "sessions")
data class SessionEntity(
    @PrimaryKey val id: String,
    val startTime: Long,
    val endTime: Long,
    val playerWeightKg: Double,
    val playerAge: Int,
    // Aggregated stats (computed on insert)
    val totalDistanceMeters: Double,
    val avgSpeedKmh: Double,
    val maxSpeedKmh: Double,
    val sprintCount: Int,
    val highIntensityDistanceMeters: Double,
    val avgHeartRate: Int,
    val maxHeartRate: Int,
    val caloriesBurned: Double,
    val slackIndex: Int,
    val slackLabel: String,
    val coveragePercent: Double,
    // Cloud sync fields (v2)
    val syncedToCloud: Boolean = false,
    val ownerUid: String? = null
)

@Entity(
    tableName = "track_points",
    foreignKeys = [ForeignKey(
        entity = SessionEntity::class,
        parentColumns = ["id"],
        childColumns = ["sessionId"],
        onDelete = ForeignKey.CASCADE
    )],
    indices = [Index("sessionId")]
)
data class TrackPointEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val sessionId: String,
    val timestamp: Long,
    val latitude: Double,
    val longitude: Double,
    val speed: Double,
    val heartRate: Int,
    val accuracy: Float
)

@Dao
interface SessionDao {
    @Query("SELECT * FROM sessions ORDER BY startTime DESC")
    suspend fun getAllSessions(): List<SessionEntity>

    @Query("SELECT * FROM sessions WHERE id = :id")
    suspend fun getSession(id: String): SessionEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSession(session: SessionEntity)

    @Delete
    suspend fun deleteSession(session: SessionEntity)

    @Query("SELECT * FROM sessions WHERE syncedToCloud = 0 AND ownerUid IS NOT NULL")
    suspend fun getUnsyncedSessions(): List<SessionEntity>

    @Query("UPDATE sessions SET syncedToCloud = 1 WHERE id = :id")
    suspend fun markSynced(id: String)

    @Query("UPDATE sessions SET ownerUid = :uid WHERE ownerUid IS NULL")
    suspend fun assignOwner(uid: String)
}

@Dao
interface TrackPointDao {
    @Query("SELECT * FROM track_points WHERE sessionId = :sessionId ORDER BY timestamp")
    suspend fun getPointsForSession(sessionId: String): List<TrackPointEntity>

    @Insert
    suspend fun insertPoints(points: List<TrackPointEntity>)

    @Query("DELETE FROM track_points WHERE sessionId = :sessionId")
    suspend fun deletePointsForSession(sessionId: String)
}

@Database(
    entities = [SessionEntity::class, TrackPointEntity::class],
    version = 2,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun sessionDao(): SessionDao
    abstract fun trackPointDao(): TrackPointDao

    companion object {
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE sessions ADD COLUMN syncedToCloud INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE sessions ADD COLUMN ownerUid TEXT DEFAULT NULL")
            }
        }
    }
}

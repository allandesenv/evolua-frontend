package com.example.evolua_frontend

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import net.zetetic.database.DatabaseErrorHandler
import net.zetetic.database.sqlcipher.SQLiteDatabase
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Unwired private storage boundary. One serial worker and one live session
 * per channel. No arbitrary SQL, file paths, credentials in logs or network.
 * The caller must authorize the profile and supply an unwrapped random DEK.
 */
class PrivateStoreChannel(context: Context, messenger: BinaryMessenger) {
    private val app = context.applicationContext
    private val channel = MethodChannel(messenger, "evolua/private_store_v1")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val preserveFile = DatabaseErrorHandler { _, _ -> }
    private var database: SQLiteDatabase? = null
    private var session: String? = null
    private var libraryLoaded = false
    private val identifier = Regex("[A-Za-z0-9_-]{1,128}")

    init {
        channel.setMethodCallHandler { call, result ->
            worker.execute {
                try {
                    val value = dispatch(call)
                    main.post { result.success(value) }
                } catch (error: Exception) {
                    val code = if (error is StoreFailure) error.code else "STORE_OPERATION_FAILED"
                    main.post { result.error(code, "Private storage operation rejected", null) }
                } catch (_: LinkageError) {
                    main.post { result.error("STORE_UNAVAILABLE", "Private storage unavailable", null) }
                }
            }
        }
    }

    fun detach() {
        channel.setMethodCallHandler(null)
        worker.execute { closeCurrent() }
        worker.shutdown()
    }

    private class StoreFailure(val code: String) : Exception()
    private fun requireStore(condition: Boolean, code: String) {
        if (!condition) throw StoreFailure(code)
    }

    private fun id(value: Any?): String {
        requireStore(value is String && identifier.matches(value), "INVALID_ID")
        return value as String
    }

    private fun longValue(value: Any?): Long {
        requireStore(value is Int || value is Long, "INVALID_NUMBER")
        val number = (value as Number).toLong()
        requireStore(number >= 0L, "INVALID_NUMBER")
        return number
    }

    private fun text(value: Any?): String {
        requireStore(value is String && value.isNotEmpty() && value.length <= 16384, "INVALID_BODY")
        val body = value as String
        requireStore(body.toByteArray(Charsets.UTF_8).size <= 65536, "INVALID_BODY")
        return body
    }

    private fun root(): File {
        val parent = app.noBackupFilesDir.canonicalFile
        val root = File(parent, "evolua-private-v1")
        if (!root.exists()) root.mkdir()
        requireStore(root.isDirectory && root.canonicalFile == root.absoluteFile, "STORE_PATH_INVALID")
        return root
    }

    private fun closeCurrent() {
        val current = database
        database = null
        session = null
        current?.close()
    }

    private fun open(profile: String, key: ByteArray, create: Boolean): String {
        requireStore(database == null, "SESSION_ALREADY_OPEN")
        requireStore(key.size == 32, "INVALID_KEY")
        if (!libraryLoaded) {
            System.loadLibrary("sqlcipher")
            libraryLoaded = true
        }
        val directory = File(root(), profile)
        requireStore(directory.canonicalFile == directory.absoluteFile, "STORE_PATH_INVALID")
        if (create) {
            // mkdir is exclusive: never open or replace an existing profile.
            requireStore(directory.mkdir(), "PROFILE_ALREADY_EXISTS")
        } else {
            requireStore(directory.isDirectory, "PROFILE_MISSING")
        }
        val file = File(directory, "private.db")
        requireStore(file.canonicalFile == file.absoluteFile, "STORE_PATH_INVALID")
        requireStore(if (create) !file.exists() else file.isFile, "DATABASE_STATE_INVALID")
        val flags = if (create) SQLiteDatabase.CREATE_IF_NECESSARY else SQLiteDatabase.OPEN_READWRITE
        val nativeKey = key.copyOf()
        var db: SQLiteDatabase? = null
        try {
            val opened = SQLiteDatabase.openDatabase(file.absolutePath, nativeKey, null, flags, preserveFile, null)
            db = opened
            if (create) {
                opened.beginTransaction()
                try {
                    opened.execSQL("CREATE TABLE private_meta(singleton INTEGER PRIMARY KEY CHECK(singleton=1), profile_id TEXT NOT NULL)")
                    opened.execSQL("INSERT INTO private_meta(singleton,profile_id) VALUES(1,?)", arrayOf<Any>(profile))
                    opened.execSQL("CREATE TABLE private_records(id TEXT PRIMARY KEY NOT NULL, created_at INTEGER NOT NULL CHECK(created_at>=0), body TEXT NOT NULL)")
                    opened.execSQL("CREATE INDEX private_records_order ON private_records(created_at DESC,id DESC)")
                    opened.execSQL("PRAGMA user_version = 1")
                    opened.setTransactionSuccessful()
                } finally { opened.endTransaction() }
            }
            requireStore(opened.version == 1, "SCHEMA_UNSUPPORTED")
            opened.rawQuery("SELECT profile_id FROM private_meta WHERE singleton=1", emptyArray<String>()).use { cursor ->
                requireStore(cursor.moveToFirst() && cursor.getString(0) == profile && !cursor.moveToNext(), "PROFILE_MISMATCH")
            }
            val handle = UUID.randomUUID().toString()
            database = opened
            session = handle
            db = null
            return handle
        } finally {
            nativeKey.fill(0)
            db?.close()
            // Interrupted creation may leave a partial profile; fail closed.
            // Recovery/removal must be an explicit later operation.
        }
    }

    private fun active(call: MethodCall): SQLiteDatabase {
        val handle = call.argument<String>("session")
        val current = database
        requireStore(current != null && session != null && session == handle, "SESSION_INVALID")
        return current!!
    }

    private fun insert(call: MethodCall): Int {
        val db = active(call)
        val rows = call.argument<List<*>>("records")
        requireStore(rows != null && rows.size in 1..100, "INVALID_BATCH")
        val validated = rows!!.map {
            requireStore(it is Map<*, *>, "INVALID_RECORD")
            val row = it as Map<*, *>
            Triple(id(row["id"]), longValue(row["createdAt"]), text(row["body"]))
        }
        db.beginTransaction()
        try {
            for ((id, time, body) in validated) {
                db.execSQL("INSERT INTO private_records(id,created_at,body) VALUES(?,?,?)", arrayOf<Any>(id, time, body))
            }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
        return validated.size
    }

    private fun page(call: MethodCall): List<Map<String, Any>> {
        val db = active(call)
        val limit = longValue(call.argument<Any>("limit"))
        requireStore(limit in 1L..100L, "INVALID_LIMIT")
        val beforeTime = call.argument<Any>("beforeTime")
        val beforeId = call.argument<Any>("beforeId")
        requireStore((beforeTime == null) == (beforeId == null), "INVALID_CURSOR")
        val sql = if (beforeTime == null) {
            "SELECT id,created_at,body FROM private_records ORDER BY created_at DESC,id DESC LIMIT ?"
        } else {
            "SELECT id,created_at,body FROM private_records WHERE created_at < ? OR (created_at = ? AND id < ?) ORDER BY created_at DESC,id DESC LIMIT ?"
        }
        val args = if (beforeTime == null) arrayOf(limit.toString()) else {
            val time = longValue(beforeTime).toString()
            arrayOf(time, time, id(beforeId), limit.toString())
        }
        val result = mutableListOf<Map<String, Any>>()
        db.rawQuery(sql, args).use { cursor ->
            while (cursor.moveToNext()) {
                result.add(mapOf("id" to cursor.getString(0), "createdAt" to cursor.getLong(1), "body" to cursor.getString(2)))
            }
        }
        return result
    }

    private fun dispatch(call: MethodCall): Any? = when (call.method) {
        "create", "open" -> {
            val key = call.argument<ByteArray>("key") ?: throw StoreFailure("INVALID_KEY")
            try { open(id(call.argument<Any>("profile")), key, call.method == "create") }
            finally { key.fill(0) }
        }
        "insertBatch" -> insert(call)
        "page" -> page(call)
        "close" -> { active(call); closeCurrent(); null }
        else -> throw StoreFailure("METHOD_UNSUPPORTED")
    }
}

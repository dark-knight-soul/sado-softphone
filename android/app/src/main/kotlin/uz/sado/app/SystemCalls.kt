package uz.sado.app

import android.content.Context
import android.net.Uri
import android.os.Build
import android.telecom.DisconnectCause
import androidx.core.telecom.CallAttributesCompat
import androidx.core.telecom.CallControlScope
import androidx.core.telecom.CallEndpointCompat
import androidx.core.telecom.CallsManager
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch

/**
 * Связь с системой звонков Android (Telecom) — пробный режим, по умолчанию выключен.
 *
 * Зачем: пока Android не знает о звонке приложения, он не передаёт ему кнопку гарнитуры, не показывает
 * звонок в машине и на часах, а обычный сотовый звонок может отобрать звук посреди разговора. Здесь
 * приложение сообщает системе о каждом своём звонке, а система в ответ присылает команды: «ответить»,
 * «завершить», «удержать» — и сама ведёт список устройств звука.
 *
 * Сам звонок по-прежнему ведёт код Dart; этот класс только пересказывает его состояние системе и
 * команды системы — обратно ([SadoEngine.send]). Если система отказала (нет такой службы, занята линия),
 * звонок идёт как раньше, без неё.
 *
 * Всё, кроме пометок состояния, выполняется в главном потоке.
 */
object SystemCalls {
    private const val RINGING = 0
    private const val ACTIVE = 1
    private const val HELD = 2
    private const val ENDED = 3

    /** Что Dart просит передать системе про один звонок. */
    private sealed interface Command {
        data object Active : Command
        data object Held : Command
        data class Ended(val cause: Int) : Command
        data class Route(val kind: String) : Command
    }

    private class Entry(val incoming: Boolean) {
        /** Очередь просьб: копится, пока система ещё не приняла звонок, и разбирается после. */
        val commands = Channel<Command>(Channel.UNLIMITED)

        @Volatile
        var state = RINGING

        /** На входящий уже ответили (мы или система) — дальше это «снять с удержания», а не «ответить». */
        @Volatile
        var answered = false

        @Volatile
        var endpoints: List<CallEndpointCompat> = emptyList()

        @Volatile
        var current: CallEndpointCompat? = null
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val calls = HashMap<Int, Entry>()
    private var manager: CallsManager? = null
    private var refused = false

    /** Есть ли в телефоне система звонков, которой можно сообщать о своих звонках. */
    fun supported(app: Context): Boolean {
        if (Build.VERSION.SDK_INT < 26 || refused) return false
        val pm = app.packageManager
        return pm.hasSystemFeature("android.software.telecom") ||
            pm.hasSystemFeature("android.software.connectionservice")
    }

    private fun manager(app: Context): CallsManager? {
        manager?.let { return it }
        if (!supported(app)) return null
        return try {
            CallsManager(app).also {
                it.registerAppWithTelecom(CallsManager.CAPABILITY_BASELINE)
                manager = it
            }
        } catch (e: Exception) {
            // Система не дала зарегистрироваться (урезанная прошивка, нет разрешения) — больше не пробуем.
            refused = true
            null
        }
    }

    /** Появился звонок. [id] — номер звонка в приложении, по нему же приходят команды системы. */
    fun start(app: Context, id: Int, number: String, name: String?, incoming: Boolean) {
        if (calls.containsKey(id)) return
        val manager = manager(app) ?: return
        val entry = Entry(incoming)
        calls[id] = entry
        scope.launch {
            try {
                val attributes = CallAttributesCompat(
                    displayName = if (name.isNullOrBlank()) number else name,
                    address = Uri.fromParts("tel", number, null),
                    direction = if (incoming) CallAttributesCompat.DIRECTION_INCOMING else CallAttributesCompat.DIRECTION_OUTGOING,
                    callType = CallAttributesCompat.CALL_TYPE_AUDIO_CALL,
                    callCapabilities = CallAttributesCompat.SUPPORTS_SET_INACTIVE,
                )
                // Возвращается, только когда звонок закончился (или система его не приняла — тогда исключение).
                manager.addCall(
                    attributes,
                    onAnswer = {
                        entry.answered = true
                        entry.state = ACTIVE
                        tell(id, "answer")
                    },
                    onDisconnect = {
                        entry.state = ENDED
                        tell(id, "hangUp")
                    },
                    onSetActive = {
                        entry.state = ACTIVE
                        tell(id, "unhold")
                    },
                    onSetInactive = {
                        entry.state = HELD
                        tell(id, "hold")
                    },
                ) {
                    launch { for (command in entry.commands) run(entry, command) }
                    launch {
                        availableEndpoints.collect {
                            entry.endpoints = it
                            tellRoutes(id, entry)
                        }
                    }
                    launch {
                        currentCallEndpoint.collect {
                            entry.current = it
                            tellRoutes(id, entry)
                        }
                    }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // Система не приняла звонок (например, идёт сотовый разговор и вторую линию она не даёт).
                // Звонок в приложении от этого не зависит.
            } finally {
                entry.commands.close()
                if (calls[id] === entry) calls.remove(id)
                SadoEngine.send("systemCallGone", id)
            }
        }
    }

    /** Звонок соединён ([held] = false) или поставлен на удержание. */
    fun state(id: Int, held: Boolean) {
        calls[id]?.commands?.trySend(if (held) Command.Held else Command.Active)
    }

    /** Звонок закончился. [reason]: local, remote, rejected или missed. */
    fun end(id: Int, reason: String) {
        val cause = when (reason) {
            "remote" -> DisconnectCause.REMOTE
            "rejected" -> DisconnectCause.REJECTED
            "missed" -> DisconnectCause.MISSED
            else -> DisconnectCause.LOCAL
        }
        calls[id]?.commands?.trySend(Command.Ended(cause))
    }

    /** Человек выбрал в приложении, куда выводить звук: earpiece, speaker, bluetooth или wired. */
    fun route(id: Int, kind: String) {
        calls[id]?.commands?.trySend(Command.Route(kind))
    }

    private suspend fun CallControlScope.run(entry: Entry, command: Command) {
        try {
            when (command) {
                Command.Active -> if (entry.state != ACTIVE && entry.state != ENDED) {
                    if (entry.incoming && !entry.answered) {
                        entry.answered = true
                        answer(CallAttributesCompat.CALL_TYPE_AUDIO_CALL)
                    } else {
                        setActive()
                    }
                    entry.state = ACTIVE
                }
                Command.Held -> if (entry.state == ACTIVE) {
                    setInactive()
                    entry.state = HELD
                }
                is Command.Ended -> if (entry.state != ENDED) {
                    entry.state = ENDED
                    disconnect(DisconnectCause(command.cause))
                }
                is Command.Route -> {
                    val type = endpointType(command.kind)
                    entry.endpoints.firstOrNull { it.type == type }?.let { requestEndpointChange(it) }
                }
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            // Система отказала в одной просьбе — звонок в приложении продолжается.
        }
    }

    private fun tell(id: Int, action: String) {
        SadoEngine.send("systemCall", mapOf("id" to id, "action" to action))
    }

    private fun tellRoutes(id: Int, entry: Entry) {
        val routes = entry.endpoints.mapNotNull { endpoint ->
            kindOf(endpoint.type)?.let { mapOf("kind" to it, "name" to endpoint.name.toString()) }
        }
        SadoEngine.send(
            "systemRoutes",
            mapOf("id" to id, "routes" to routes, "current" to entry.current?.let { kindOf(it.type) }),
        )
    }

    private fun kindOf(type: Int): String? = when (type) {
        CallEndpointCompat.TYPE_EARPIECE -> "earpiece"
        CallEndpointCompat.TYPE_SPEAKER -> "speaker"
        CallEndpointCompat.TYPE_BLUETOOTH -> "bluetooth"
        CallEndpointCompat.TYPE_WIRED_HEADSET -> "wired"
        else -> null
    }

    private fun endpointType(kind: String): Int = when (kind) {
        "earpiece" -> CallEndpointCompat.TYPE_EARPIECE
        "speaker" -> CallEndpointCompat.TYPE_SPEAKER
        "bluetooth" -> CallEndpointCompat.TYPE_BLUETOOTH
        "wired" -> CallEndpointCompat.TYPE_WIRED_HEADSET
        else -> CallEndpointCompat.TYPE_UNKNOWN
    }
}

package app.zapline.player

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.View
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.datasource.HttpDataSource
import androidx.media3.exoplayer.drm.DrmSessionManagerProvider
import androidx.media3.exoplayer.hls.DefaultHlsExtractorFactory
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.upstream.DefaultLoadErrorHandlingPolicy
import androidx.media3.exoplayer.upstream.LoadErrorHandlingPolicy
import androidx.media3.exoplayer.source.preload.DefaultPreloadManager
import androidx.media3.exoplayer.source.preload.TargetPreloadStatusControl
import androidx.media3.extractor.DefaultExtractorsFactory
import androidx.media3.session.MediaSession
import androidx.media3.extractor.ts.DefaultTsPayloadReaderFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Zapline's own player (Dart: Media3Engine). Each player screen gets one
 * ExoPlayer that stays for the whole screen: a zap only changes what it
 * plays, instead of building a new player, decoder and surface each time.
 * Pictures and subtitles carried in the stream are drawn by a PlayerView
 * shown as a platform view ("zapline/media3-view").
 */
@OptIn(UnstableApi::class)
class Media3Host(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val sessions = mutableMapOf<Int, Media3Session>()

    /**
     * Switches the screen to suit a frame rate (MainActivity), or back to
     * its own mode with null.
     */
    var frameRate: ((Float?) -> Unit)? = null
    private var sink: EventChannel.EventSink? = null

    // Views made before their player (the two arrive on different
    // channels): attached as soon as it exists.
    private val waiting = mutableMapOf<Int, PlayerView>()

    fun attachWhenReady(id: Int, view: PlayerView) {
        val s = sessions[id]
        if (s != null) s.attach(view) else waiting[id] = view
    }

    fun forget(id: Int, view: PlayerView) {
        if (waiting[id] === view) waiting.remove(id)
        sessions[id]?.detach(view)
    }

    init {
        MethodChannel(messenger, "zapline/media3").setMethodCallHandler(this)
        EventChannel(messenger, "zapline/media3/events").setStreamHandler(this)
    }

    fun session(id: Int): Media3Session? = sessions[id]

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Int>("id") ?: return result.error("id", "No player id", null)
        if (call.method == "create") {
            sessions.remove(id)?.release()
            val s = Media3Session(
                id,
                context,
                call.argument<Boolean>("background") == true,
                if (call.argument<Boolean>("matchFrameRate") == true) {
                    { rate -> frameRate?.invoke(rate) }
                } else null,
            ) { sink?.success(it) }
            sessions[id] = s
            waiting.remove(id)?.let { s.attach(it) }
            return result.success(null)
        }
        val s = sessions[id] ?: return result.success(null)
        when (call.method) {
            "open" -> s.open(
                call.argument<String>("url")!!,
                call.argument<Map<String, String>>("headers") ?: emptyMap(),
                (call.argument<Number>("startMs") ?: 0).toLong(),
            )
            "preload" -> s.preload(
                (call.argument<Number>("current") ?: -1).toInt(),
                (call.argument<List<Map<String, Any?>>>("items") ?: emptyList()).mapNotNull {
                    val i = (it["index"] as? Number)?.toInt()
                    val u = it["url"] as? String
                    if (i == null || u == null) null else i to u
                },
            )
            "stop" -> s.player.stop()
            "play" -> s.player.play()
            "pause" -> s.player.pause()
            "seek" -> s.player.seekTo((call.argument<Number>("ms") ?: 0).toLong())
            "setVolume" -> s.player.volume = (call.argument<Double>("value") ?: 1.0).toFloat()
            "setFit" -> s.setFit(call.argument<String>("fit") ?: "contain")
            "tracks" -> return result.success(s.tracks(call.argument<String>("type") ?: "audio"))
            "selectTrack" -> s.select(
                call.argument<String>("type") ?: "audio",
                call.argument<String>("track"),
            )
            "dispose" -> {
                sessions.remove(id)?.release()
                waiting.remove(id)
            }
            else -> return result.notImplemented()
        }
        result.success(null)
    }

    fun releaseAll() {
        sessions.values.forEach { it.release() }
        sessions.clear()
        waiting.clear()
    }
}

@OptIn(UnstableApi::class)
class Media3Session(
    private val id: Int,
    private val context: Context,
    background: Boolean,
    private val frameRate: ((Float?) -> Unit)?,
    private val emit: (Map<String, Any?>) -> Unit,
) : Player.Listener {

    private val http = DefaultHttpDataSource.Factory()
        .setAllowCrossProtocolRedirects(true)
        .setConnectTimeoutMs(8_000)
        .setReadTimeoutMs(15_000)

    // IPTV streams are mostly raw MPEG-TS: start on the first picture that
    // can be shown instead of waiting for a full key frame, and find
    // access units in streams that don't mark them.
    private val extractors = DefaultExtractorsFactory().setTsExtractorFlags(
        DefaultTsPayloadReaderFactory.FLAG_ALLOW_NON_IDR_KEYFRAMES or
            DefaultTsPayloadReaderFactory.FLAG_DETECT_ACCESS_UNITS
    )

    // The channel playing, by its index in the list being zapped; the ones
    // next to it get their first seconds loaded (preload), the rest none.
    private var playingIndex = -1

    private val preloadControl =
        TargetPreloadStatusControl<Int, DefaultPreloadManager.PreloadStatus> { rank ->
            if (Math.abs(rank - playingIndex) == 1) {
                // Two seconds: enough to show the picture at once.
                DefaultPreloadManager.PreloadStatus.specifiedRangeLoaded(2_000)
            } else {
                DefaultPreloadManager.PreloadStatus.PRELOAD_STATUS_NOT_PRELOADED
            }
        }

    private val sources = DefaultMediaSourceFactory(DefaultDataSource.Factory(context, http), extractors)

    // HLS gets the same picture flags for its TS segments, and CEA-608
    // captions even when the playlist doesn't declare them.
    private val hls = HlsMediaSource.Factory(DefaultDataSource.Factory(context, http))
        .setExtractorFactory(
            DefaultHlsExtractorFactory(
                DefaultTsPayloadReaderFactory.FLAG_ALLOW_NON_IDR_KEYFRAMES or
                    DefaultTsPayloadReaderFactory.FLAG_DETECT_ACCESS_UNITS,
                true,
            )
        )

    // The player and the preload manager share their threads, load control
    // and sources, as Media3 wants for a preloaded source to play.
    private val builder = DefaultPreloadManager.Builder(context, preloadControl)
        .setRenderersFactory(
            DefaultRenderersFactory(context).setEnableDecoderFallback(true)
        )
        .setMediaSourceFactory(
            Routing(sources, hls).setLoadErrorHandlingPolicy(DeadChannelPolicy())
        )
        // Start after 1 s, after a stall 2 s (Media3's defaults); keep
        // 15-40 s ahead instead of 50: less memory on a Fire TV Stick.
        .setLoadControl(
            DefaultLoadControl.Builder()
                .setBufferDurationsMs(15_000, 40_000, 1_000, 2_000)
                // At most 48 MB however high the bitrate: the default lets
                // a 4K stream take over 100 MB of a 1 GB stick.
                .setTargetBufferBytes(48 * 1024 * 1024)
                .build()
        )

    val player: ExoPlayer = builder.buildExoPlayer().also { it.addListener(this) }
    private val preloader: DefaultPreloadManager = builder.build()

    /** An item handed to the preloader, and when. */
    private class Preloaded(val index: Int, val item: MediaItem, val at: Long)

    /** Items handed to the preloader, by URL: the same instance finds its source. */
    private val preloaded = mutableMapOf<String, Preloaded>()

    private fun itemFor(url: String): MediaItem {
        val b = MediaItem.Builder().setUri(url).setMediaId(url)
        if (url.substringBefore('?').lowercase().endsWith(".m3u8")) {
            b.setMimeType(MimeTypes.APPLICATION_M3U8)
        }
        return b.build()
    }

    /**
     * Loads the first seconds of [items] (index in the list, address) next
     * to [current]; an empty list lets them all go, closing their
     * connections (many providers allow only one or two at a time).
     */
    fun preload(current: Int, items: List<Pair<Int, String>>) {
        playingIndex = current
        val keep = items.map { it.second }.toSet()
        val gone = preloaded.filterKeys { it !in keep }
        gone.forEach { (url, entry) ->
            preloader.remove(entry.item)
            preloaded.remove(url)
        }
        for ((index, url) in items) {
            if (url in preloaded || url == playingUrl) continue
            val item = itemFor(url)
            preloaded[url] = Preloaded(index, item, SystemClock.elapsedRealtime())
            preloader.add(item, index)
        }
        preloader.setCurrentPlayingIndex(current)
        preloader.invalidate()
    }

    private var playingUrl: String? = null

    /** The preloader's item now played, released when another plays. */
    private var playingPreloaded: MediaItem? = null

    private var view: PlayerView? = null
    private var fit = AspectRatioFrameLayout.RESIZE_MODE_FIT
    private val ticker = Handler(Looper.getMainLooper())
    private var firstFrame = false

    private val tick = object : Runnable {
        override fun run() {
            if (player.isPlaying) emitPosition()
            ticker.postDelayed(this, 500)
        }
    }

    // Sound in the background: a media session for the system's media
    // controls and a service that keeps the app alive with a notification.
    private val mediaSession: MediaSession? =
        if (background) MediaSession.Builder(context, player).setId("zapline-$id").build()
        else null

    init {
        ticker.postDelayed(tick, 500)
        mediaSession?.let {
            PlaybackService.session = it
            // A service still running for the player screen before (a
            // channel opened from the list over the picture) takes this
            // session over; otherwise it is started now, while the app is
            // on screen: Android doesn't let an app in the background.
            val running = PlaybackService.instance
            if (running != null) running.addSession(it)
            else context.startService(Intent(context, PlaybackService::class.java))
        }
    }

    fun open(url: String, headers: Map<String, String>, startMs: Long) {
        firstFrame = false
        http.setUserAgent(headers["User-Agent"])
        http.setDefaultRequestProperties(headers.filterKeys { it != "User-Agent" })
        playingUrl = url
        // A preloaded channel plays from what it already has; it is then
        // the player's, and not preloaded again until it is let go.
        // Loaded more than 10 s ago, a live stream's first seconds are
        // behind live and its connection may be gone: opened afresh.
        var entry = if (startMs == 0L) preloaded.remove(url) else null
        if (entry != null && SystemClock.elapsedRealtime() - entry.at > 10_000) {
            preloader.remove(entry.item)
            entry = null
        }
        val source = entry?.let { preloader.getMediaSource(it.item) }
        val before = playingPreloaded
        playingPreloaded = if (source != null) entry?.item else null
        if (source != null) {
            player.setMediaSource(source)
        } else {
            player.setMediaItem(itemFor(url), startMs)
        }
        // The previous channel's preloaded source, no longer played.
        before?.let { preloader.remove(it) }
        player.prepare()
        player.playWhenReady = true
    }

    fun attach(v: PlayerView) {
        view = v
        v.resizeMode = fit
        v.player = player
    }

    fun detach(v: PlayerView) {
        if (view === v) {
            v.player = null
            view = null
        }
    }

    fun setFit(name: String) {
        fit = when (name) {
            "cover" -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM
            "fill" -> AspectRatioFrameLayout.RESIZE_MODE_FILL
            else -> AspectRatioFrameLayout.RESIZE_MODE_FIT
        }
        view?.resizeMode = fit
    }

    private fun trackType(type: String) =
        if (type == "text") C.TRACK_TYPE_TEXT else C.TRACK_TYPE_AUDIO

    /** "group:track" ids with labels, languages and which is on. */
    fun tracks(type: String): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        player.currentTracks.groups.forEachIndexed { g, group ->
            if (group.type != trackType(type)) return@forEachIndexed
            for (t in 0 until group.length) {
                if (!group.isTrackSupported(t)) continue
                val f = group.getTrackFormat(t)
                out.add(
                    mapOf(
                        "id" to "$g:$t",
                        "label" to f.label,
                        "language" to f.language,
                        "selected" to group.isTrackSelected(t),
                    )
                )
            }
        }
        return out
    }

    /** Picks a track by its "group:track" id; text `null` turns subtitles off. */
    fun select(type: String, track: String?) {
        val kind = trackType(type)
        val params = player.trackSelectionParameters.buildUpon()
        if (track == null) {
            params.setTrackTypeDisabled(kind, true)
        } else {
            val (g, t) = track.split(':').map { it.toInt() }
            val group: Tracks.Group = player.currentTracks.groups.getOrNull(g) ?: return
            params.setTrackTypeDisabled(kind, false)
                .setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, t))
        }
        player.trackSelectionParameters = params.build()
    }

    private fun emitPosition() {
        // Live streams can report 0 at their start: the first frame still
        // counts as playing, which ends the zap.
        val pos = player.currentPosition.coerceAtLeast(if (firstFrame) 1 else 0)
        emit(mapOf("id" to id, "event" to "position", "ms" to pos))
    }

    override fun onRenderedFirstFrame() {
        firstFrame = true
        emit(mapOf("id" to id, "event" to "picture"))
        emitPosition()
    }

    override fun onPlaybackStateChanged(state: Int) {
        emit(mapOf("id" to id, "event" to "buffering", "value" to (state == Player.STATE_BUFFERING)))
        if (state == Player.STATE_ENDED) emit(mapOf("id" to id, "event" to "ended"))
        if (state == Player.STATE_READY) {
            val d = player.duration
            emit(
                mapOf(
                    "id" to id,
                    "event" to "duration",
                    "ms" to if (d == C.TIME_UNSET) 0L else d,
                    "live" to (d == C.TIME_UNSET || player.isCurrentMediaItemLive),
                )
            )
        }
    }

    private var rateAsked = 0f

    override fun onTracksChanged(tracks: Tracks) {
        // What of the stream this device can play: neither sound nor
        // picture means a black, silent screen that should count as failed.
        if (!tracks.isEmpty) {
            emit(
                mapOf(
                    "id" to id,
                    "event" to "tracks",
                    "audio" to tracks.isTypeSupported(C.TRACK_TYPE_AUDIO),
                    "video" to tracks.isTypeSupported(C.TRACK_TYPE_VIDEO),
                )
            )
        }
        val ask = frameRate ?: return
        val video = tracks.groups.firstOrNull {
            it.type == C.TRACK_TYPE_VIDEO && it.isSelected
        } ?: return
        val format = (0 until video.length).firstOrNull { video.isTrackSelected(it) }
            ?.let { video.getTrackFormat(it) } ?: return
        val rate = format.frameRate
        // Unknown (many TS streams don't say), or as asked already.
        if (rate <= 0f || rate == rateAsked) return
        rateAsked = rate
        ask(rate)
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        emit(mapOf("id" to id, "event" to "playing", "value" to isPlaying))
    }

    override fun onPlayerError(error: PlaybackException) {
        // A live stream fell behind what the server still keeps: back to
        // live, as players do, rather than an error.
        if (error.errorCode == PlaybackException.ERROR_CODE_BEHIND_LIVE_WINDOW) {
            player.seekToDefaultPosition()
            player.prepare()
            return
        }
        // A preloaded source kept too long may have gone stale: the retry
        // opens the channel afresh.
        playingPreloaded?.let { preloader.remove(it) }
        playingPreloaded = null
        val cause = error.cause?.message
        emit(
            mapOf(
                "id" to id,
                "event" to "error",
                "message" to if (cause.isNullOrBlank()) error.errorCodeName else "${error.errorCodeName}: $cause",
            )
        )
    }

    fun release() {
        if (rateAsked > 0f) frameRate?.invoke(null)
        mediaSession?.let {
            PlaybackService.instance?.removeSession(it)
            // Stopped only if no newer session plays through it.
            if (PlaybackService.session === it) {
                PlaybackService.session = null
                context.stopService(Intent(context, PlaybackService::class.java))
            }
            it.release()
        }
        preloader.release()
        preloaded.clear()
        playingPreloaded = null
        ticker.removeCallbacks(tick)
        view?.player = null
        view = null
        player.removeListener(this)
        player.release()
    }
}

/** The picture of a [Media3Session], made by Flutter's platform views. */
class Media3ViewFactory(private val host: Media3Host) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val id = (params?.get("id") as? Number)?.toInt() ?: -1
        return Media3View(context, host, id)
    }
}

@OptIn(UnstableApi::class)
class Media3View(context: Context, private val host: Media3Host, private val id: Int) :
    PlatformView {
    private val playerView = PlayerView(context).apply {
        useController = false
        setShutterBackgroundColor(Color.BLACK)
    }

    init {
        host.attachWhenReady(id, playerView)
    }

    override fun getView(): View = playerView

    override fun dispose() {
        host.forget(id, playerView)
    }
}

/** HLS to its own factory (for its TS flags), everything else to the default. */
@OptIn(UnstableApi::class)
private class Routing(
    private val other: MediaSource.Factory,
    private val hls: MediaSource.Factory,
) : MediaSource.Factory {
    override fun setDrmSessionManagerProvider(p: DrmSessionManagerProvider) = apply {
        other.setDrmSessionManagerProvider(p)
        hls.setDrmSessionManagerProvider(p)
    }

    override fun setLoadErrorHandlingPolicy(p: LoadErrorHandlingPolicy) = apply {
        other.setLoadErrorHandlingPolicy(p)
        hls.setLoadErrorHandlingPolicy(p)
    }

    override fun getSupportedTypes(): IntArray = other.supportedTypes

    override fun createMediaSource(item: MediaItem): MediaSource =
        if (item.localConfiguration?.mimeType == MimeTypes.APPLICATION_M3U8) {
            hls.createMediaSource(item)
        } else {
            other.createMediaSource(item)
        }
}

/**
 * A channel the server refuses is told at once instead of after a few
 * seconds of retries: the player screen says so, or tries the channel's
 * other version. The server failing (5xx) gets two quick retries.
 */
@OptIn(UnstableApi::class)
private class DeadChannelPolicy : DefaultLoadErrorHandlingPolicy() {
    override fun getRetryDelayMsFor(info: LoadErrorHandlingPolicy.LoadErrorInfo): Long {
        val e = info.exception
        if (e is HttpDataSource.InvalidResponseCodeException) {
            val code = e.responseCode
            return when {
                // The playlist or the stream itself refused: no retry. A
                // live playlist's segment may be gone a moment: one retry.
                code in 400..499 ->
                    if (info.mediaLoadData.dataType == C.DATA_TYPE_MANIFEST ||
                        info.errorCount > 1
                    ) C.TIME_UNSET else 500L
                code in 500..599 ->
                    if (info.errorCount <= 2) 500L * info.errorCount else C.TIME_UNSET
                else -> super.getRetryDelayMsFor(info)
            }
        }
        return super.getRetryDelayMsFor(info)
    }
}

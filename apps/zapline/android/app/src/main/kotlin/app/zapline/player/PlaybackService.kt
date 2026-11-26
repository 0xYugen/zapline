package app.zapline.player

import android.content.Intent
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

/**
 * Keeps a channel's sound going with the app in the background (phones,
 * when chosen in Settings): Media3 shows the media notification and runs
 * this service in the foreground while the player plays. The session is
 * the player screen's (Media3Session); it comes and goes with it.
 */
@OptIn(UnstableApi::class)
class PlaybackService : MediaSessionService() {

    override fun onCreate() {
        super.onCreate()
        session?.let { addSession(it) }
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? =
        session

    // Swiped away from recent apps: the sound stops with the app.
    override fun onTaskRemoved(rootIntent: Intent?) {
        session?.player?.pause()
        stopSelf()
    }

    companion object {
        /** The player screen's session, set while one plays. */
        var session: MediaSession? = null
    }
}

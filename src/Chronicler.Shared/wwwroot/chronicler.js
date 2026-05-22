window.chroniclerAudio = {
    play: (el) => {
        if (!el) return;
        console.log('[chronicler] play src=' + el.src + ' readyState=' + el.readyState);
        el.play().catch(e => console.error('[chronicler] play error:', e));
    },
    pause: (el) => { if (el) el.pause(); },
    seek: (el, pos) => { if (el) el.currentTime = pos; },
    setRate: (el, rate) => { if (el) el.playbackRate = rate; },
    currentTime: (el) => el ? el.currentTime : 0,
    duration: (el) => (el && !isNaN(el.duration)) ? el.duration : 0,
    isPaused: (el) => !el || el.paused,

    // Called when Blazor updates the src attribute — just trigger load()
    reload: (el) => {
        if (!el) return;
        console.log('[chronicler] reload src=' + el.src);
        el.load();
    },

    // Register event callbacks from Blazor
    registerEvents: (el, dotnetRef) => {
        if (!el) return;
        el.addEventListener('play',           () => dotnetRef.invokeMethodAsync('OnJsPlay'));
        el.addEventListener('pause',          () => dotnetRef.invokeMethodAsync('OnJsPause'));
        el.addEventListener('ended',          () => dotnetRef.invokeMethodAsync('OnJsEnded'));
        el.addEventListener('loadedmetadata', () => dotnetRef.invokeMethodAsync('OnJsMetadata', el.duration));
        // Throttle timeupdate to 1/sec — iOS WKWebView bridge can't keep up at 4/sec
        let lastUpdate = 0;
        el.addEventListener('timeupdate', () => {
            const now = Date.now();
            if (now - lastUpdate >= 250) {
                lastUpdate = now;
                dotnetRef.invokeMethodAsync('OnJsTimeUpdate', el.currentTime);
            }
        });
    }
};

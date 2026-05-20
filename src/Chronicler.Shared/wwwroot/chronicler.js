window.chroniclerAudio = {
    play: (el) => { if (el) el.play(); },
    pause: (el) => { if (el) el.pause(); },
    seek: (el, pos) => { if (el) el.currentTime = pos; },
    setRate: (el, rate) => { if (el) el.playbackRate = rate; },
    currentTime: (el) => el ? el.currentTime : 0,
    duration: (el) => (el && !isNaN(el.duration)) ? el.duration : 0,
    isPaused: (el) => !el || el.paused,

    // Register event callbacks from Blazor
    registerEvents: (el, dotnetRef) => {
        if (!el) return;
        el.addEventListener('play',        () => dotnetRef.invokeMethodAsync('OnJsPlay'));
        el.addEventListener('pause',       () => dotnetRef.invokeMethodAsync('OnJsPause'));
        el.addEventListener('ended',       () => dotnetRef.invokeMethodAsync('OnJsEnded'));
        el.addEventListener('timeupdate',  () => dotnetRef.invokeMethodAsync('OnJsTimeUpdate', el.currentTime));
        el.addEventListener('loadedmetadata', () => dotnetRef.invokeMethodAsync('OnJsMetadata', el.duration));
    }
};

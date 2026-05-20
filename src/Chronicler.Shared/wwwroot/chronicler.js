function diagLog(msg) {
    console.log('[chronicler]', msg);
    try {
        fetch('/api/diag', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({message: msg}) });
    } catch(e) {}
}

window.chroniclerAudio = {
    play: (el) => { if (el) el.play(); },
    pause: (el) => { if (el) el.pause(); },
    seek: (el, pos) => { if (el) el.currentTime = pos; },
    setRate: (el, rate) => { if (el) el.playbackRate = rate; },
    currentTime: (el) => el ? el.currentTime : 0,
    duration: (el) => (el && !isNaN(el.duration)) ? el.duration : 0,
    isPaused: (el) => !el || el.paused,
    load: (el, src) => {
        if (!el) { diagLog('load: el is null, src=' + src); return; }
        diagLog('load called, src=' + src);
        el.src = src;
        el.load();
        diagLog('load() done, readyState=' + el.readyState + ' networkState=' + el.networkState);
        el.addEventListener('loadstart',    () => diagLog('loadstart src=' + src));
        el.addEventListener('canplay',      () => diagLog('canplay'));
        el.addEventListener('error',        () => diagLog('error code=' + (el.error?.code) + ' msg=' + el.error?.message + ' src=' + src));
        el.addEventListener('stalled',      () => diagLog('stalled'));
        el.addEventListener('suspend',      () => diagLog('suspend'));
    },

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

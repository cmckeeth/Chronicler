window.chroniclerAudio = {
    play: (el) => el.play(),
    pause: (el) => el.pause(),
    seek: (el, pos) => { el.currentTime = pos; },
    setRate: (el, rate) => { el.playbackRate = rate; },
    currentTime: (el) => el.currentTime,
    duration: (el) => el.duration || 0,
};

# Demo video
Frame-stepped capture of the local page (Playwright) + Python compositor (captions, cursor, window frame) → ffmpeg.
Order: `node assets.js; node s2.js; node rest.js s3 s4; node fix.js; node rest.js s5 s6 s8; node s7.js; python3 scenes.py el; python3 scenes.py en`, then concat `out/s0..s9_<lang>.mp4`.
The agent scene replays a stored answer through the real ask() path (the live agent only runs inside Claude); the refusal text was written for the video.

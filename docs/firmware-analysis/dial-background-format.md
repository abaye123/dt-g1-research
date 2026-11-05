# Custom clock background / photo format (user_clock_bg.bin)

Reverse-engineered from the watch (2026-11-06) using two samples: a photo
background (`res/user_clock_bg.bin`) and a video clock background.

A custom photo dial background is a 16-byte header followed by a 466x466 JPEG:

```
offset  size  meaning
0x00    2     u16 LE  = 0x0009   (type/version; 9 = image)
0x02    3     u24 LE  = length of the JPEG that follows
0x05    3     bytes   = D2 21 1D (fixed signature, same on all samples)
0x08    8     zero
0x10    ...   the JPEG data (JFIF, 466x466)
```

Verified: for the photo sample, u24@2 = 116329 = exactly the JPEG byte length.
For a video clock background the same header is followed by a JPEG thumbnail
(u24@2 = its length) and then the video stream. No checksum is used.

Files on the watch (partition 2, `/1:/res/`):
- `user_clock_bg.bin`   - the full 466x466 background.
- `user_clock_thumb.bin` - the thumbnail. In the observed sample it was byte-for-byte identical to the background.

The photo gallery files `/0:/photo/photo_XXXX.res` use the same 16-byte header,
followed by a full JPEG and then a thumbnail JPEG.

To set a custom background over USB: build the file as above and write it to
`res/user_clock_bg.bin` and `res/user_clock_thumb.bin` on the hidden partition,
then select the photo/custom dial on the watch. (Not yet verified end to end on
the watch; test when connected.)

# blndr

![blndr](https://user-images.githubusercontent.com/6550035/89369521-2f47e980-d693-11ea-8ca1-be69b9e00534.jpg)

this is `blndr` - my first patch for [norns](https://monome.org/docs/norns/). `blndr` is a quantized delay with optional time bending effects in the stereo field.

## demo

[![demo screenshot](![vlcsnap-2020-08-04-21h42m08s210](https://user-images.githubusercontent.com/6550035/89372587-6621fd80-d69b-11ea-98e2-c013fac69565.png)](https://www.instagram.com/p/CDfppIbBFnF)


## requirements

- norns
- line-in

## documentation

the line-in audio is fed into a delay loop for a duration of one quarter note, so it automatically becomes quantized to the `bpm` (ENC1). the amount of delay can be dialed in with `feedback` (ENC2).

![main screen](https://user-images.githubusercontent.com/6550035/89369525-3111ad00-d693-11ea-887b-0543bb2efe6f.jpg)

the delay loop is randomly time shifted based on the probability from the `spin` parameter (ENC3). the audio from the delay loop is then fed into a second delay loop that is also time shifted and panned randomly.

the KEY2/3 are used to quickly speed up/down the bpm to 1/3 intervals to get some cool polyrhythms (good for drums).

this would not have been possible without the stellar [softcut tutorial](https://monome.org/docs/norns/softcut/) and inspiration of randomizing speed shifts from [bounds](https://llllllll.co/t/bounds/23336). 




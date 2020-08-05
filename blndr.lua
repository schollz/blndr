--  ___.-.___
--  =========
--  | blndr |
--  | v0.1  |
--  |       |
--  |  >|<  |
--  \:\|/:/
--  /"""""\
-- |_______|
--
-- E1 sets bpm
-- E2 sets feedback
-- E3 makes it spin
-- KEY2/3 dec/inc bpm
-- multiplier (good for drums)
--
-- 

rate = 1.0
feedback = 0.5
bpm = 90
speeds = {1,1}
spin = 0.25
pan = 0.5
multipliers = {1/3,2/3,1,1+1/3,1+2/3,2}
mi = 3
m = metro.init()
m.time = 60/bpm*2*multipliers[mi]
m.event = function()
  local speeds = {0.25, 0.5, 1, 2, 4}
  for i=1,2 do
      local new_speed = 1
      if math.random() < spin then
        neg = 1
        if math.random() < 0.5 then
          neg = -1
        end
        new_speed = neg * speeds[math.random(#speeds)]
        if i == 2 then
          pan = pan * -1
          softcut.pan(2, pan)
        end
      end
      if new_speed ~= speeds[i] then
        speeds[i] = new_speed
        softcut.rate(i,speeds[i])
      end
  end
end

function init()
  -- send audio input to softcut input
  audio.level_adc_cut(1)
  softcut.buffer_clear()

  for i=1,2 do
    softcut.enable(i,1)
    softcut.buffer(i,i)
    softcut.loop(i,1)
    softcut.loop_start(i,1)
    softcut.loop_end(i,1+60/bpm)
    softcut.position(i,1)
    softcut.play(i,1)
    softcut.rec_level(i,feedback)
    softcut.pre_level(i,feedback)
    softcut.rec(i,1)
    softcut.rate(i,1)
    softcut.rate_slew_time(i,60/bpm*1.5)
    softcut.pan_slew_time(i,60/bpm*1.5)
  end

  -- send input audio to channel 1
  softcut.level_input_cut(1,1,1.0)
  softcut.level_input_cut(2,1,1.0)
  -- send output of channel 1 to channel 2
  softcut.level_cut_cut(1,2,1)
  softcut.pan(2, pan)
  softcut.level(1,1.0)
  softcut.level(2,0.8)
  softcut.post_filter_lp(2,1.0)
  softcut.post_filter_fc(2,18000)


  m:start()
end

function enc(n,d)
  if n==1 then
    bpm = bpm + d*0.25
    for i=1,2 do
      softcut.loop_end(i,1+60/bpm*multipliers[mi])
      softcut.rate_slew_time(i,60/bpm*1.5)
      softcut.pan_slew_time(i,60/bpm*1.5)
    end
    m.time = 60/bpm*2*multipliers[mi]
  elseif n==2 then
    feedback = util.clamp(feedback + d*0.01,0,1)
    for i=1,2 do
      softcut.rec_level(i,feedback)
      softcut.pre_level(i,feedback)
    end
  elseif n==3 then
    spin = util.clamp(spin + d*0.01,0,1)
  end
  redraw()
end

function key(n,z)
  if n==3 and z == 1 then
    if mi < 6 then
      mi = mi + 1
      for i=1,2 do
        softcut.loop_end(i,1+60/bpm*multipliers[mi])
      end
      m.time = 60/bpm*2*multipliers[mi]
    end
  elseif n==2 and z == 1 then
    if mi > 1 then
      mi = mi - 1
      for i=1,2 do
        softcut.loop_end(i,1+60/bpm*multipliers[mi])
      end
      m.time = 60/bpm*2*multipliers[mi]
    end
  end
  redraw()
end

function redraw()
  screen.clear()
  screen.move(10,10)
  screen.text("blndr v0.1")
  screen.move(10,30)
  screen.text("bpm: ")
  screen.move(118,30)
  screen.text_right(string.format("%.2f",bpm))
  screen.move(10,40)
  screen.text("feedback: ")
  screen.move(118,40)
  screen.text_right(string.format("%.2f",feedback))
  screen.move(10,50)
  screen.text("spin: ")
  screen.move(118,50)
  screen.text_right(string.format("%.2f",spin))
  screen.move(10,60)
  screen.text("multiplier: ")
  screen.move(118,60)
  screen.text_right(string.format("x%.2f",multipliers[mi]))
  screen.update()
end


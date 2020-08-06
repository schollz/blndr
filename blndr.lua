--  ___.-.___
--  =========
--  | blndr |
--  | v0.2  |
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

shift = 0
monitor_linein = 1
rate = 1.0
feedback = 1.0
spin = 1.0
bpm = 90
speeds = {1,1}
pan = 0.5
multipliers = {1/3,2/3,1,1+1/3,1+2/3,2}
mi = 3
m = metro.init()
m.time = 60/(bpm*multipliers[mi])
m.event = function()
  local speeds_sel = {0.25, 0.25, 0.5, 0.75, 1}
  for i=1,2 do
      local new_speed = 1
      if math.random() < spin then
        neg = 1
        if math.random() < 0.5 then
          neg = -1
        end
      	for i=1,10 do
          new_speed = neg * speeds_sel[math.random(#speeds_sel)]
      	  if math.abs(new_speed/speeds[i]) <= 2 then
      	    break
          end
      	end
        if i == 1 then
          pan = pan * -1
          softcut.pan(i, pan)
        else
          softcut.pan(i,-1*pan)
        end
      end
      if new_speed ~= speeds[i] then
        speeds[i] = new_speed
        softcut.rate(i,speeds[i])
        m.time = 60/(bpm*multipliers[mi])/speeds[1]
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
    softcut.rec_level(i,0.5)
    softcut.pre_level(i,0.5)
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
  softcut.pan(1, -1*pan)
  softcut.pan(2, pan)
  softcut.level(1,feedback)
  softcut.level(2,feedback)
  softcut.post_filter_lp(2,1.0)
  softcut.post_filter_fc(2,15000)
  softcut.post_filter_lp(1,1.0)
  softcut.post_filter_fc(1,15000)


  m:start()
end

function enc(n,d)
  if n==1 then
    bpm = bpm + d*0.25
    for i=1,2 do
      softcut.loop_end(i,1+60/(bpm*multipliers[mi]))
      softcut.level_slew_time(i,60/(bpm*multipliers[mi]))
      softcut.rate_slew_time(i,60/(bpm*multipliers[mi])*0.5)
      softcut.pan_slew_time(i,60/(bpm*multipliers[mi]))
    end
    m.time = 60/(bpm*multipliers[mi])/speeds[1]
  elseif n==2 then
    feedback = util.clamp(feedback + d*0.01,0,1)
    for i=1,2 do
      softcut.level(1,feedback)
      softcut.level(2,feedback)
    end
  elseif n==3 then
    spin = util.clamp(spin + d*0.01,0,1)
  end
  redraw()
end

function key(n,z)
  if shift ==1 and n==2 and z==1 then
    monitor_linein = 1 - monitor_linein
    audio.level_monitor(monitor_linein)
  elseif n==3 and z == 1 then
    if mi < 6 then
      mi = mi + 1
      for i=1,2 do
        softcut.loop_end(i,1+60/(bpm*multipliers[mi]))
      end
      m.time = 60/(bpm*multipliers[mi])/speeds[1]
    end
  elseif n==2 and z == 1 then
    if mi > 1 then
      mi = mi - 1
      for i=1,2 do
        softcut.loop_end(i,1+60/(bpm*multipliers[mi]))
      end
       m.time = 60/(bpm*multipliers[mi])/speeds[1]
    end
  elseif n==1 and z==1 then
	  shift = 1
  elseif n==1 and z==0 then
	  shift = 0
  end
  redraw()
end

function redraw()
  screen.clear()
  screen.move(10,10)
  screen.text("blndr v0.2")
  screen.move(118,10)
  if monitor_linein == 0 then
    screen.text("x")
  else
    screen.text(">")
  end
  screen.move(10,30)
  screen.text("bpm: ")
  screen.move(118,30)
  screen.text_right(string.format("%.2f",(bpm*multipliers[mi])))
  screen.move(10,40)
  screen.text("level: ")
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


--  ___.-.___
--  =========
--  | blndr |
--  | v0.3  |
--  |       |
--  |  >|<  |
--  \:\|/:/
--  /"""""\
-- |_______|
--
-- llllllll.co/t/blndr
--
-- E1 sets bpm
-- E2 sets level
-- E3 makes it spin
-- K1+E2 sets feedback
-- K1+E1 toggles monitor
-- K2/K3 dec/inc bpm
-- multiplier (good for drums)
--
-- 

shift = 0
monitor_linein = 1
rate = 1.0
level = 0.0
feedback = 0.5
spin = 0.0
bpm = 90
speeds = {1,1}
pan = 0.5
multipliers = {1/3,2/3,1,1+1/3,1+2/3,2}
mi = 3
m = metro.init()
m.time = 60/(bpm*multipliers[mi])
m.event = function()
  -- event should run every 2 beats at current speed
  -- m.time = 60/(bpm*multipliers[mi])/math.abs(speeds[1])*2
  -- time   = 60s/min/(beats / minute)/(current speed)*(2 beats)
  local speeds_sel = {0.25, 0.25, 0.5, 0.75, 1}
  for i=1,2 do
      local new_speed = speeds[i]
      -- revert approximately every 8 beats
      if math.random() < 0.25 then 
        new_speed = 1
        -- if speeds[i] < 0 then
        --   new_speed = -1
        -- end
      end
      if math.random() < spin then
        neg = 1
        if math.random() < 0.5 then
          neg = -1
        end
        -- find a speed that isn't 4x, since that is too high pitched
        for j=1,10 do
          new_speed = neg * speeds_sel[math.random(#speeds_sel)]
          break
          print(new_speed,speeds[i])
          if math.abs(new_speed/speeds[i]) <= 2 then
            break
          end
        end
        -- reverse pans
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
        if i == 1 then
          -- set new time based on new speed
          m.time = 60/(bpm*multipliers[mi])/math.abs(speeds[1])*2
        end
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
    softcut.level(i,level)
    softcut.post_filter_lp(i,1.0)
    softcut.post_filter_fc(i,15000)
    softcut.pan(i,((i*2)-3)*pan)
  end

  -- send input audio to channel 1
  softcut.level_input_cut(1,1,1.0)
  softcut.level_input_cut(2,1,1.0)
  -- send output of channel 1 to channel 2
  softcut.level_cut_cut(1,2,1)

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
    if shift == 0 then 
      level = util.clamp(level + d*0.01,0,1)
      for i=1,2 do
        softcut.level(i,level)
      end
    else
      feedback = util.clamp(feedback + d*0.01,0,1)
      for i=1,2 do
        softcut.rec_level(i,feedback)
        softcut.pre_level(i,feedback)
      end
    end
  elseif n==3 then
    spin = util.clamp(spin + d*0.01,0,1)
    -- if spin == 0 then
    --     softcut.rate(1,1)
    --     softcut.rate(2,1)
    -- end
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
      m.time = 60/(bpm*multipliers[mi])/math.abs(speeds[1])*2
    end
  elseif n==2 and z == 1 then
    if mi > 1 then
      mi = mi - 1
      for i=1,2 do
        softcut.loop_end(i,1+60/(bpm*multipliers[mi]))
      end
      m.time = 60/(bpm*multipliers[mi])/math.abs(speeds[1])*2
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
  screen.text("blndr v0.3")
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
  if shift == 0 then
    screen.text("level: ")
    screen.move(118,40)
    screen.text_right(string.format("%.2f",level))
  else 
    screen.text("feedback: ")
    screen.move(118,40)
    screen.text_right(string.format("%.2f",feedback))
  end
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


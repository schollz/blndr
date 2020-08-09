--  ___-___
--  |       |  blndr 
--  |       |  v0.4
--  |       |  a quantized delay
--  |  >|<.  |  w/ time bending
--  \.\|/./
--  /"""""\ 
-- |_______|
--
-- llllllll.co/t/blndr
--
-- E1 sets bpm
-- E2 sets level
-- E3 makes it spin
-- K1+E2 sets feedback
-- K1+K2 toggles monitor
-- K1+K3 toggles reverse mode
-- K2/K3 dec/inc bpm
-- multiplier (good for drums)

engine.name = 'InputTutorial'

screen_count = 0
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
count = 1
reverse_mode = 0
m = metro.init()
m.time = 60/(bpm*multipliers[mi])
m.event = function()
  if reverse_mode == 1 then
    -- reverse mode
    -- count goes between 1 and 2
    count = 3 - count
    speeds[count] = speeds[count]*-1
    softcut.rate(count,speeds[count])
    softcut.level(count,level)
    softcut.level(3-count,0)
    softcut.level_slew_time(count,60/(bpm*multipliers[mi])*0.25)
    softcut.level_slew_time(3-count,60/(bpm*multipliers[mi])*0.02)
    do return end
  end


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

function repoll()
  p_amp_in:update()
end

refresh_rate = 1.0 / 15
re = metro.init()
re.time = refresh_rate
re.event = function()
  repoll()
  redraw()
end
re:start()

function init()
  -- send audio input to softcut input
  audio.level_adc_cut(1)
  softcut.buffer_clear()


  -- Listen
  audio.monitor_mono()
  engine.amp(1.0)
  -- Poll in
  p_amp_in = poll.set("amp_in_l")
  p_amp_in.time = refresh_rate
  p_amp_in.callback = function(val) 
    if val > 0.05 then 
      print(val)
    end
  end

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
    if spin == 0 then
      for i=1,2 do
        softcut.pan(i,0)
      end
    else 
      for i=1,2 do
        if reverse_mode == 0 then
          softcut.pan(i,((i*2)-3)*pan)
        else
          softcut.pan(i,((i*2)-3)*spin)
        end
      end
    end
  end
  redraw()
end

function key(n,z)
  if shift ==1 and n==2 and z==1 then
    monitor_linein = 1 - monitor_linein
    audio.level_monitor(monitor_linein)
  elseif shift == 1 and n ==3 and z == 1 then
    -- toggle blndr mode / reverse mode
    reverse_mode = 1 - reverse_mode
    if reverse_mode == 0 then 
      -- blndr mode 
      softcut.buffer_clear()
      m.time = 60/(bpm*multipliers[mi])/math.abs(speeds[1])*2
      -- send input audio to channel 1
      softcut.level_input_cut(1,1,1.0)
      softcut.level_input_cut(2,1,1.0)
      -- send output of channel 1 to channel 2
      softcut.level_cut_cut(1,2,1)
      for i=1,2 do 
        softcut.pan(i,((i*2)-3)*pan)
        softcut.level_slew_time(i,60/(bpm*multipliers[mi]))
        softcut.rate_slew_time(i,60/(bpm*multipliers[mi])*0.5)
      end
    else
      -- reverse mode
      softcut.buffer_clear()
      m.time = 60/(bpm*multipliers[mi])
      -- clear output from 1 to 2
      softcut.level_cut_cut(1,2,0)
      for i=1,2 do 
        -- each channel listens to itself
        softcut.level_input_cut(i,i,1.0)
        softcut.level_slew_time(i,60/(bpm*multipliers[mi])*0.25)
        softcut.rate_slew_time(i,60/(bpm*multipliers[mi])*0.25)
        softcut.pan_slew_time(i,60/(bpm*multipliers[mi])*0.25)
        softcut.pan(i,((i*2)-3)*spin)
      end
    end
    for i=1,2 do 
      speeds[i] = 1
      softcut.rate(i,1)
    end
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
  screen_count = 1 - screen_count
  screen.clear()
  screen.move(10,10)
  blendertext = ">|<"
  if screen_count == 1 then 
    blendertext = "<|>"
  end
  screen.text(blendertext.." blndr v0.4")
  if monitor_linein == 0 then
    screen.move(78,20)
    screen.text("ext only")
  end
  if reverse_mode == 1 then
    screen.move(78,10)
    screen.text("rev mode")
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
  if reverse_mode == 0 then
    screen.text("spin: ")
  else
    screen.text("pan: ")
  end
  screen.move(118,50)
  screen.text_right(string.format("%.2f",spin))
  -- screen.move(10,60)
  -- screen.text("multiplier: ")
  -- screen.move(118,60)
  -- screen.text_right(string.format("x%.2f",multipliers[mi]))
  screen.update()
end


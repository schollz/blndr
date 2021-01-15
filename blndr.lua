--  ___-___
--  |       |  blndr
--  |       |  v0.6
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

local Formatters=require 'formatters'

state_lastbpm=0
screen_count=0
shift=0
monitor_linein=1
rate=1.0
bpm=90
speeds={1,1,1,1}
pan=0.5
multipliers={1/3,2/3,1,1+1/3,1+2/3,2}
mi=3
count=1
reverse_mode=0


function init()
  audio.comp_mix(1) -- turn on compressor
  -- send audio input to softcut input
  audio.level_adc_cut(1)

  -- add parameters
  params:add_control("delay level","delay level",controlspec.new(0,1,"lin",0,0,"",1/100))
  params:set_action("delay level",function(x)
    softcut.level(1,x)
    softcut.level(3,x)
  end)
  params:add_control("feedback","feedback",controlspec.new(0,1,"lin",0,.5,"",1/100))
  params:set_action("feedback",function(x)
    for i=1,4 do
      softcut.rec_level(i,x)
      softcut.pre_level(i,x)
    end
  end)
  params:add_control("spin level","spin level",controlspec.new(0,1,"lin",0,0,"",1/100))
  params:set_action("spin level",function(x)
    softcut.level(2,x)
    softcut.level(4,x)
  end)
  params:add_control("spin","spin",controlspec.new(0,1,"lin",0,0,"",1/100))
  params:set_action("spin",function(x)
    if x==0 then
      for i=1,4 do
        softcut.pan(i,0)
      end
    else
      for i=1,4 do
        if reverse_mode==0 then
          softcut.pan(1,-1*pan)
          softcut.pan(2,pan)
          softcut.pan(3,pan)
          softcut.pan(4,-1*pan)
        else
          softcut.pan(1,-1*x)
          softcut.pan(2,x)
          softcut.pan(3,x)
          softcut.pan(4,-1*x)
        end
      end
    end
  end)
  filter_resonance=controlspec.new(0,.9,'lin',0,0,'')
  filter_freq=controlspec.new(20,20000,'exp',0,5000,'Hz')
  params:add {
      type='control',
      id='filter_frequency',
      name='filter cutoff',
      controlspec=filter_freq,
      formatter=Formatters.format_freq,
      action=function(value)
        for i=1,4 do
          softcut.post_filter_fc(i,value)
        end
      end
    }
  params:add {
    type='control',
    id='filter_reso',
    name='filter resonance',
    controlspec=filter_resonance,
    action=function(value)
      for i=1,4 do
        softcut.post_filter_rq(i,1-value)
      end
    end
  }
  softcut.buffer_clear() 
  for i=1,4 do
    softcut.enable(i,1)
    softcut.buffer(i,i)
    softcut.loop(i,1)
    softcut.loop_start(i,1+i*10)
    softcut.loop_end(i,1+60/bpm+i*10)
    softcut.position(i,1)
    softcut.play(i,1)
    softcut.rec_level(i,params:get("feedback"))
    softcut.pre_level(i,params:get("feedback"))
    softcut.rec(i,1)
    softcut.rate(i,1)
    softcut.rate_slew_time(i,60/bpm*1.5)
    softcut.pan_slew_time(i,60/bpm*1.5)
    softcut.post_filter_dry(i,0.0)
    softcut.post_filter_lp(i,1.0)
    softcut.post_filter_rq(i,1.0)
    softcut.post_filter_fc(i,20100)
    softcut.pre_filter_dry(i,1.0)
    softcut.pre_filter_lp(i,1.0)
    softcut.pre_filter_rq(i,1.0)
    softcut.pre_filter_fc(i,20100)
  end
  softcut.level(1,params:get("delay level"))
  softcut.level(2,params:get("spin"))
  softcut.level(3,params:get("delay level"))
  softcut.level(4,params:get("spin"))
  softcut.pan(1,-1*pan)
  softcut.pan(2,pan)
  softcut.pan(3,pan)
  softcut.pan(4,-1*pan)


  -- send input audio to channel 1
  softcut.level_input_cut(1,1,1.0)
  softcut.level_input_cut(2,3,1.0)
  -- send output of channel 1 to channel 2
  softcut.level_cut_cut(1,2,1)
  softcut.level_cut_cut(3,4,1)
  

  m=metro.init()
  m.time=60/(bpm*multipliers[mi])
  m.event=function()
    if reverse_mode==1 then
      -- reverse mode
      -- count goes between 1 and 2
      count=3-count
      speeds[count]=speeds[count]*-1
      softcut.rate(count,speeds[count])
      softcut.level_slew_time(count,60/(bpm*multipliers[mi])*0.25)
      softcut.level_slew_time(3-count,60/(bpm*multipliers[mi])*0.02)
      speeds[count+2]=speeds[count+2]*-1
      softcut.rate(count+2,speeds[count+2])
      softcut.level_slew_time(count+2,60/(bpm*multipliers[mi])*0.25)
      softcut.level_slew_time(3-count+2,60/(bpm*multipliers[mi])*0.02)
      do return end
    end
    
    -- event should run every 2 beats at current speed
    -- m.time = 60/(bpm*multipliers[mi])/math.abs(speeds[1])*2
    -- time   = 60s/min/(beats / minute)/(current speed)*(2 beats)
    local speeds_sel={0.25,0.25,0.5,0.75,1,2}
    for i=1,4 do
      local new_speed=speeds[i]
      -- revert approximately every 8 beats
      if math.random()<0.1 then
        new_speed=1
        -- if speeds[i] < 0 then
        --   new_speed = -1
        -- end
      end
      if math.random()<params:get("spin") then
        neg=1
        if math.random()<0.5 then
          neg=-1
        end
        -- find a speed that isn't 4x, since that is too high pitched
        for j=1,10 do
          new_speed=neg*speeds_sel[math.random(#speeds_sel)]
          break
          print(new_speed,speeds[i])
          if math.abs(new_speed/speeds[i])<=2 then
            break
          end
        end
        -- reverse pans
        if i==1 or i==3 then
          pan=pan*-1
          softcut.pan(i,pan)
        else
          softcut.pan(i,-1*pan)
        end
      end
      if new_speed~=speeds[i] then
        speeds[i]=new_speed
        softcut.rate(i,speeds[i])
        if i==1 then
          -- set new time based on new speed
          m.time=60/(bpm*multipliers[mi])/math.abs(speeds[1])*2
        end
      end
    end
  end
  m:start()
  
  updater=metro.init()
  updater.time=0.25
  updater.count=-1
  updater.event=update_parms
  updater:start()
  
end

function update_parms()
  if bpm~=state_lastbpm then
    state_lastbpm=bpm
    for i=1,4 do
      softcut.loop_end(i,1+60/(bpm*multipliers[mi])+i*10)
      softcut.level_slew_time(i,60/(bpm*multipliers[mi]))
      softcut.rate_slew_time(i,60/(bpm*multipliers[mi])*0.5)
      softcut.pan_slew_time(i,60/(bpm*multipliers[mi]))
    end
    m.time=60/(bpm*multipliers[mi])/speeds[1]
  end
  redraw()
end

function enc(n,d)
  if n==1 then
    bpm=util.clamp(bpm+d*0.25,20,400)
  elseif n==2 then
    if shift==0 then
      params:set("delay level",params:get("delay level")+d*0.01)
    else
      params:set("feedback",params:get("feedback")+d*0.01)
    end
  elseif n==3 then
    params:set("spin",params:get("spin")+d*0.01)
    params:set("spin level",params:get("spin level")+d*0.01)
  end
  redraw()
end

function key(n,z)
  if shift==1 and n==2 and z==1 then
    monitor_linein=1-monitor_linein
    audio.level_monitor(monitor_linein)
  elseif shift==1 and n==3 and z==1 then
    -- toggle blndr mode / reverse mode
    reverse_mode=1-reverse_mode
    if reverse_mode==0 then
      -- blndr mode
      softcut.buffer_clear()
      m.time=60/(bpm*multipliers[mi])/math.abs(speeds[1])*2
      -- send input audio to channel 1
      softcut.level_input_cut(1,1,1.0)
      softcut.level_input_cut(2,3,1.0)
      -- send output of channel 1 to channel 2
      softcut.level_cut_cut(1,2,1)
      softcut.level_cut_cut(3,4,1)
      for i=1,4 do
        softcut.level_slew_time(i,60/(bpm*multipliers[mi]))
        softcut.rate_slew_time(i,60/(bpm*multipliers[mi])*0.5)
      end
      softcut.pan(1,-1*pan)
      softcut.pan(2,pan)
      softcut.pan(3,pan)
      softcut.pan(4,-1*pan)
    else
      -- reverse mode
      softcut.buffer_clear()
      m.time=60/(bpm*multipliers[mi])
      -- clear output from 1 to 2
      softcut.level_cut_cut(1,2,0)
      softcut.level_cut_cut(3,4,0)
      for i=1,4 do
        -- each channel listens to itself
        softcut.level_input_cut(i,i,1.0)
        softcut.level_slew_time(i,60/(bpm*multipliers[mi])*0.25)
        softcut.rate_slew_time(i,60/(bpm*multipliers[mi])*0.25)
        softcut.pan_slew_time(i,60/(bpm*multipliers[mi])*0.25)
      end
      softcut.pan(1,-1*pan*params:get("spin"))
      softcut.pan(2,pan*params:get("spin"))
      softcut.pan(3,pan*params:get("spin"))
      softcut.pan(4,-1*pan*params:get("spin"))
    end
    for i=1,4 do
      speeds[i]=1
      softcut.rate(i,1)
    end
  elseif n==3 and z==1 then
    if mi<6 then
      mi=mi+1
      for i=1,4 do
        softcut.loop_end(i,1+60/(bpm*multipliers[mi])+i*10)
      end
      m.time=60/(bpm*multipliers[mi])/math.abs(speeds[1])*2
    end
  elseif n==2 and z==1 then
    if mi>1 then
      mi=mi-1
      for i=1,4 do
        softcut.loop_end(i,1+60/(bpm*multipliers[mi])+i*10)
      end
      m.time=60/(bpm*multipliers[mi])/math.abs(speeds[1])*2
    end
  elseif n==1 and z==1 then
    shift=1
  elseif n==1 and z==0 then
    shift=0
  end
  redraw()
end

function redraw()
  screen_count=1-screen_count
  screen.clear()
  screen.move(10,10)
  if shift==1 then
    screen.move(13,13)
  end
  blendertext=">|<"
  if screen_count==1 then
    blendertext="<|>"
  end
  screen.text(blendertext.." blndr v0.6")
  if monitor_linein==0 then
    screen.move(78,20)
    screen.text("ext only")
  end
  if reverse_mode==1 then
    screen.move(78,10)
    screen.text("rev mode")
  end
  screen.move(10,30)
  screen.text("bpm: ")
  screen.move(118,30)
  screen.text_right(string.format("%.2f",(bpm*multipliers[mi])))
  screen.move(10,40)
  if shift==0 then
    screen.text("level: ")
    screen.move(118,40)
    screen.text_right(string.format("%.2f",params:get("delay level")))
  else
    screen.text("feedback: ")
    screen.move(118,40)
    screen.text_right(string.format("%.2f",params:get("feedback")))
  end
  screen.move(10,50)
  if reverse_mode==0 then
    screen.text("spin: ")
  else
    screen.text("pan: ")
  end
  screen.move(118,50)
  screen.text_right(string.format("%.2f",params:get("spin")))
  screen.update()
end


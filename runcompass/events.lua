local Events = {}

function Events.normalized(controller)
  local function emit(name)
    return function() controller.onEvent(name) end
  end
  return {
    run = emit("RUN_STARTED"),
    level = emit("FLOOR_CHANGED"),
    room = emit("ROOM_CHANGED"),
    pickup = emit("OBSERVATION_CHANGED"),
    player = emit("PLAYER_STATE_CHANGED"),
    progress = emit("PROGRESS_CHANGED"),
    target = emit("TARGET_CHANGED")
  }
end

return Events

local Controller = {}
Controller.__index = Controller

local INVALIDATING_EVENTS = {
  RUN_STARTED = true,
  FLOOR_CHANGED = true,
  ROOM_CHANGED = true,
  OBSERVATION_CHANGED = true,
  PLAYER_STATE_CHANGED = true,
  PROGRESS_CHANGED = true,
  TARGET_CHANGED = true
}

function Controller.new(planner)
  return setmetatable({ planner = planner, dirty = true, previous = nil, goalId = nil, recommendation = nil }, Controller)
end

function Controller:onEvent(eventName)
  if INVALIDATING_EVENTS[eventName] then self.dirty = true end
end

function Controller:tick(snapshot, goal)
  if self.goalId ~= (goal and goal.id) then
    self.goalId = goal and goal.id
    self.dirty = true
  end
  if self.dirty then
    self.recommendation = self.planner.plan(snapshot, goal, self.previous)
    self.previous = self.recommendation
    self.dirty = false
  end
  return self.recommendation
end

function Controller:getRecommendation()
  return self.recommendation
end

return Controller

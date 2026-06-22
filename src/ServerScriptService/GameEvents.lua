local GameEvents = {}

-- Fired by GliderHandler when a player's glider touches down.
-- Payload: (player: Player, distance: number)
-- Distance is the horizontal (XZ-plane) magnitude from launch point to landing point.
GameEvents.RunEnded = Instance.new("BindableEvent")

return GameEvents

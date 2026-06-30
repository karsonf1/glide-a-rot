local GameEvents = {}

-- Fired by GliderHandler when a player's glider touches down.
-- Payload: (player: Player, distance: number)
-- Distance is the horizontal (XZ-plane) magnitude from launch point to landing point.
GameEvents.RunEnded = Instance.new("BindableEvent")

-- Fired by FuelSystem when a player's fuel hits zero mid-run.
-- Payload: (player: Player)
-- GliderHandler listens to this and fires RunEnded so it fires exactly once per run.
GameEvents.FuelDepleted = Instance.new("BindableEvent")

return GameEvents

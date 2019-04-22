defmodule DemoWeb.Pong.Ball do
    #Speed is measured in pixels per tick
    @enforce_keys [ :bounds ]
    defstruct(
      score: 0,
      bounds: nil,
      size: 16,
      position: %{x: 200, y: 122},
      speed: %{x: 20, y: 5}
    )

    def get_intersect(ball) do
      slope = ball.speed.y / ball.speed.x
      offset = ball.position.y - slope * ball.position.x
      # Add/Subtract half ball size to offset to account for ball width
      intersect = if ball.speed.y < 0 do
        (ball.bounds.y.min - offset + ball.size/2) / slope
      else
        (ball.bounds.y.max - offset - ball.size/2) / slope
      end
      cond do
        intersect > ball.bounds.x.max -> intersect - (intersect - ball.bounds.x.max)
        intersect < ball.bounds.x.min -> intersect + (ball.bounds.x.min - intersect)
        true -> intersect
      end
    end

    def is_out_of_bounds?(ball, direction, by_amount) when direction in [:x, :y] do
      ball.position[direction] + by_amount < ball.bounds[direction].min or 
      ball.position[direction] - by_amount > ball.bounds[direction].max
    end
    def is_out_of_bounds?(ball, by_amount \\ 0) do
      is_out_of_bounds?(ball, :x, by_amount) or is_out_of_bounds?(ball, :y, by_amount)
    end

    def will_go_out_of_bounds?(ball, direction) when direction in [:x, :y] do
      cond do
        ball.speed[direction] < 0 -> ball.position[direction] - ball.size / 2 + ball.speed[direction] < ball.bounds[direction].min
        ball.speed[direction] >= 0 -> ball.position[direction] + ball.size / 2 + ball.speed[direction] > ball.bounds[direction].max
      end
    end

    defp bounce(ball, direction) when direction in [:x, :y] do
      position = ball.position[direction]
      points = if direction == :y do
        1
      else
        0
      end
      overshoot = cond do
        position < ball.bounds[direction].min -> position - ball.bounds[direction].min
        position > ball.bounds[direction].max -> ball.bounds[direction].max - position
        :else -> 0
      end
      ball
      |> struct(%{speed: Map.put(ball.speed, direction, -ball.speed[direction])})
      |> struct(%{position: Map.put(ball.position, direction, position - ball.speed[direction] + overshoot)})
      |> struct(%{score: ball.score + points})
    end

    def next_position(ball, can_bounce, direction) when direction in [:x, :y] do
      if will_go_out_of_bounds?(ball, direction) and can_bounce and not is_out_of_bounds?(ball, direction, 0) do
        ball
        |> bounce(direction)
      else
        ball
        |> struct(%{position: Map.put(ball.position, direction, ball.position[direction] + ball.speed[direction])})
      end
    end

    def next_position(ball, can_bounce_directions) do
      ball
      |> next_position(:x in can_bounce_directions, :x)
      |> next_position(:y in can_bounce_directions, :y)
    end
  end
defmodule DemoWeb.Pong.Ball do
    #Speed is measured in pixels per tick
    @enforce_keys [ :bounds ]
    defstruct(
      bounds: nil,
      size: 16,
      position: %{x: 200, y: 222},
      speed: %{x: 2, y: -5},
    )

    defp bounce_ball(ball, direction) when direction in [:x, :y] do
    end

    def get_intersect(ball) do
      slope = ball.speed.y / ball.speed.x
      offset = ball.position.y - slope * ball.position.x
      if ball.speed.y < 0 do
        (ball.bounds.y.min - offset) / slope
      else
        (ball.bounds.y.max - offset) / slope
      end
    end

    def will_go_out_of_bounds?(ball, direction) when direction in [:x, :y] do
      cond do
        ball.speed[direction] < 0 -> ball.position[direction] + ball.speed[direction] < ball.bounds[direction].min
        ball.speed[direction] >= 0 -> ball.position[direction] + ball.speed[direction] > ball.bounds[direction].max
      end
    end

    defp bounce(ball, direction) when direction in [:x, :y] do
      position = ball.position[direction]
      overshoot = cond do
        position < ball.bounds[direction].min -> position - ball.bounds[direction].min
        position > ball.bounds[direction].max -> ball.bounds[direction].max - position
        :else -> 0
      end
      ball
      |> struct(%{speed: Map.put(ball.speed, direction, -ball.speed[direction])})
      |> struct(%{position: Map.put(ball.position, direction, position - ball.speed[direction] + overshoot)})
    end

    def next_position(ball, direction) when direction in [:x, :y] do
      if will_go_out_of_bounds?(ball, direction) do
        ball
        |> bounce(direction)
      else
        ball
        |> struct(%{position: Map.put(ball.position, direction, ball.position[direction] + ball.speed[direction])})
      end
    end

    def next_position(ball) do
      ball
      |> next_position(:x)
      |> next_position(:y)
    end
  end
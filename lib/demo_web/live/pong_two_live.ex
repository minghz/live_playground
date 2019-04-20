defmodule DemoWeb.PongTwoLive do

  use Phoenix.LiveView

  @container_width 800
  @container_height 400
  @container_border 5

  @board_width @container_width - 2*@container_border
  @board_height @container_height - 2*@container_border

  @game_loop_tick 30 # 16 = 60fps
  @paddle_speed 8
  @ball_speed 5
  @ball_direction %{ne: [@ball_speed, -@ball_speed],
                    se: [@ball_speed, @ball_speed],
                    sw: [-@ball_speed, @ball_speed],
                    nw: [-@ball_speed, -@ball_speed]}

  def render(assigns) do
    ~L"""
    <h2>Welcome to Ming's superior Pong game</h2>
    <svg phx-keydown="keydown" phx-target="window" class="board" width="<%= @container_width %>" height="<%= @container_height %>" style="border: <%= @container_border %>px solid black;">
      <line x1="400" y1="30" x2="400" y2="370" stroke="black" stroke-dasharray="10, 10" stroke-width="3" />
      <text x="340" y="65" text-anchor="middle" class="score"><%= @score_1 %></text>
      <text x="460" y="65" text-anchor="middle" class="score"><%= @score_2 %></text>

      <circle class="ball" cx="<%= @ball_x %>" cy="<%= @ball_y %>" r="10" fill="black" />

      <rect class="paddle1" x="0" y="<%= @paddle_position %>" rx="5" ry="5" width="20" height="100" fill="black"/>

      <rect class="paddle2" x="770" y="<%= @paddle_position %>" rx="5" ry="5" width="20" height="100" fill="black"/>
    </svg>
    """
  end

  def mount(_session, socket) do
    if connected?(socket), do: :timer.send_interval(@game_loop_tick, self(), :tick)

    {:ok, assign(socket, container_width: @container_width,
                         container_height: @container_height,
                         container_border: @container_border,
                         paddle_position: 0,
                         ball_x: 750, ball_y: 350, ball_direction: :se,
                         score_1: 0, score_2: 0)}
  end

  def handle_info(:tick, socket) do
    {:noreply, update_game(socket)}
  end

  def handle_event("keydown", key, socket) do
    case key do
      "ArrowDown" -> {:noreply, move_paddle(socket, :down) }
      "ArrowUp" ->   {:noreply, move_paddle(socket, :up)}
      _ ->           {:noreply, assign(socket, paddle_position: socket.assigns.paddle_position)}
    end
  end

  defp move_paddle(socket, direction) do
    current_position = socket.assigns.paddle_position
    case [current_position, direction] do
      [p, :up] when p <= 0 ->
        assign(socket, paddle_position: current_position)
      [p, :down] when p >= @board_height - 100 ->
        assign(socket, paddle_position: current_position)
      [position, :up] ->
        new_position = socket.assigns.paddle_position - @paddle_speed
        assign(socket, paddle_position: new_position)
      [position, :down] ->
        new_position = socket.assigns.paddle_position + @paddle_speed
        assign(socket, paddle_position: new_position)
      _ ->
        assign(socket, paddle_position: current_position)
    end
  end

  defp update_game(socket) do
    %{ball_direction: ball_direction, ball_x: ball_x, ball_y: ball_y,
      paddle_position: paddle_position,
      score_1: score_1, score_2: score_2} = socket.assigns

    [new_score_1, new_score_2] = update_score(score_1, score_2, ball_x)

    new_ball_direction = update_ball_direction(ball_direction, ball_x, ball_y, paddle_position)
    [speed_x, speed_y] = Map.fetch!(@ball_direction, new_ball_direction)
    new_ball_x = ball_x + speed_x
    new_ball_y = ball_y + speed_y

    assign(socket,
      ball_direction: new_ball_direction, ball_x: new_ball_x, ball_y: new_ball_y,
      score_1: new_score_1,
      score_2: new_score_2)
  end

  defp update_score(score_1, score_2, ball_x) do
    cond do
      hit_right_wall(ball_x) -> [score_1 + 1, score_2]
      hit_left_wall(ball_x)  -> [score_1,     score_2 + 1]
      true                   -> [score_1,     score_2]
    end
  end

  defp update_ball_direction(ball_direction, x, y, py) do
    cond do
      # Hit paddle and a wall corner
      hit_right_paddle(x, y, py) && hit_top_wall(y)    && ball_direction == :ne -> :sw
      hit_right_paddle(x, y, py) && hit_bottom_wall(y) && ball_direction == :se -> :nw
      hit_left_paddle(x, y, py)  && hit_top_wall(y)    && ball_direction == :nw -> :se
      hit_left_paddle(x, y, py)  && hit_bottom_wall(y) && ball_direction == :sw -> :ne

      # Hitting wall corners
      hit_top_wall(y)    && hit_right_wall(x) && ball_direction == :ne -> :sw
      hit_bottom_wall(y) && hit_right_wall(x) && ball_direction == :se -> :nw
      hit_top_wall(y)    && hit_left_wall(x)  && ball_direction == :nw -> :se
      hit_bottom_wall(y) && hit_left_wall(x)  && ball_direction == :sw -> :ne

      # Hit the paddles
      hit_right_paddle(x, y, py) && ball_direction == :ne -> :nw
      hit_right_paddle(x, y, py) && ball_direction == :se -> :sw
      hit_left_paddle(x, y, py)  && ball_direction == :nw -> :ne
      hit_left_paddle(x, y, py)  && ball_direction == :sw -> :se

      # Hitting side walls
      hit_top_wall(y)    && ball_direction == :ne -> :se
      hit_bottom_wall(y) && ball_direction == :se -> :ne
      hit_top_wall(y)    && ball_direction == :nw -> :sw
      hit_bottom_wall(y) && ball_direction == :sw -> :nw

      # Hit the walls behind the paddles - should count score
      hit_right_wall(x)  && ball_direction == :ne -> :nw
      hit_right_wall(x)  && ball_direction == :se -> :sw
      hit_left_wall(x) && ball_direction == :nw -> :ne
      hit_left_wall(x) && ball_direction == :sw -> :se

      true -> ball_direction
    end
  end

  defp hit_top_wall(y)            do if y <= 10,                                           do: true, else: false end
  defp hit_bottom_wall(y)         do if y >= @board_height - 10,                           do: true, else: false end
  defp hit_left_wall(x)           do if x <= 10,                                           do: true, else: false end
  defp hit_right_wall(x)          do if x >= @board_width - 10,                            do: true, else: false end
  defp hit_right_paddle(x, y, py) do if x >= @board_width - 20 - 10 and (y in py..py+100), do: true, else: false end
  defp hit_left_paddle(x, y, py)  do if x <= 20 + 10 and (y in py+20..py+120),             do: true, else: false end

end

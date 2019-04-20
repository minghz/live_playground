defmodule DemoWeb.PongTwoLive do
  use Phoenix.LiveView

  @game_loop_tick 30 # 16 = 60fps
  @paddle_speed 10
  @ball_speed 10
  @ball_direction %{ne: [@ball_speed, -@ball_speed],
                    se: [@ball_speed, @ball_speed],
                    sw: [-@ball_speed, @ball_speed],
                    nw: [-@ball_speed, -@ball_speed]}

  def render(assigns) do
    ~L"""
    <h2>Welcome to Ming's superior Pong game</h2>
    <svg phx-keydown="keydown" phx-target="window" class="board" width=800 height=402 style="border: 2px solid black;">
      <line x1="400" y1="30" x2="400" y2="370" stroke="black" stroke-dasharray="10, 10" stroke-width="3" />
      <text x="340" y="65" text-anchor="middle" class="score"><%= @score_1 %></text>
      <text x="460" y="65" text-anchor="middle" class="score"><%= @score_2 %></text>

      <circle class="ball" cx="<%= @ball_x %>" cy="<%= @ball_y %>" r="10" fill="black" />

      <rect class="paddle1" x="1" y="<%= @paddle_position %>" rx="5" ry="5" width="20" height="100" fill="black"/>

      <rect class="paddle2" x="775" y="<%= @paddle_position %>" rx="5" ry="5" width="20" height="100" fill="black"/>
    </svg>
    """
  end

  def mount(_session, socket) do
    if connected?(socket), do: :timer.send_interval(@game_loop_tick, self(), :tick)

    {:ok, assign(socket, paddle_position: 0, ball_x: 400, ball_y: 200, ball_direction: :se, score_1: 0, score_2: 0)}
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
      [p, :down] when p >= 300 ->
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
    case ball_x do
      x when x >= 800 ->
        [score_1 + 1, score_2]
      x  when x <= 0 ->
        [score_1, score_2 + 1]
      _ ->
        [score_1, score_2]
    end
  end

  defp update_ball_direction(ball_direction, ball_x, ball_y, paddle_position) do
    case [ball_direction, ball_x, ball_y, paddle_position] do
      # Hitting side walls
      [:ne, _, y, _] when y <= 0 ->
        :se
      [:se, _, y, _] when y >= 400 ->
        :ne
      [:nw, _, y, _] when y <= 0 ->
        :sw
      [:sw, _, y, _] when y >= 400 ->
        :nw

      # Hit the walls behind the paddles - should count score
      [:ne, x, _, _] when x >= 800 ->
        :nw
      [:se, x, _, _] when x >= 800 ->
        :sw
      [:nw, x, _, _] when x <= 0 ->
        :ne
      [:sw, x, _, _] when x <= 0 ->
        :se

      # Hit the paddles - should bounce back
      [:ne, x, y, py] when x >= 775 and (y in py..py+100) ->
        :nw
      [:se, x, y, py] when x >= 775 and (y in py..py+100) ->
        :sw
      [:nw, x, y, py] when x <= 21 and (y in py+20..py+120) ->
        :ne
      [:sw, x, y, py] when x <= 21 and (y in py+20..py+120) ->
        :se

      _ ->
        ball_direction
    end
  end

end

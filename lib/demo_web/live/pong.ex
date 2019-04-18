defmodule DemoWeb.Pong do
  use Phoenix.LiveView

  @tick 20
  @ball_size 16
  @paddle_size 100
  
  #Speed is measured in pixels per tick
  @ball_speed %{x: 2, y: -20}

  @ball_position %{x: 200, y: 200}
  @player_1_position 200

  @width 400
  @height 400
  @paddle_speed 10
  @paddle_offset 50

  defmacro x_min(), do: @ball_size/2
  defmacro x_max(), do: @width - @ball_size/2
  defmacro y_min(), do: @paddle_offset + @ball_size/2
  defmacro y_max(), do: @height - @paddle_offset - @ball_size/2

  def render(%{game_state: :over} = assigns) do
    ~L"""
    <div class="pong-container">
      <div class="game-over">
        <h1>GAME OVER <small>SCORE: <%= @score %></h1>
        <button phx-click="new_game">NEW GAME</button>
      </div>
    </div>
    """
  end

  def render(%{game_state: :playing} = assigns) do
    ~L"""
    <div class="pong-options">
      <form phx-change="update_settings">
        <select name="tick" onchange="this.blur()">
          <option value="5" <%= if @tick == 50, do: "selected" %>>50</option>
          <option value="10" <%= if @tick == 100, do: "selected" %>>100</option>
          <option value="20" <%= if @tick == 200, do: "selected" %>>200</option>
          <option value="50" <%= if @tick == 500, do: "selected" %>>500</option>
        </select>
        <input type="range" min="5" max="50" name="width" value="<%= @ball_size %>" />
        <%= @ball_size %>px
      </form>
    </div>
    <h3 class="score">SCORE:&nbsp;<%= @score %></h3>
    <div
      class="pong-container"
      phx-keydown="keydown"
      phx-keyup="keyup"
      phx-target="window"
      style="
        position: relative;
        height: <%= @height %>px;
        width: <%= @width %>px;
        background-color: #222;
      "
    >
      <div
        class="ball"
        style="
          position:absolute;
          left: <%= @ball_position.x - @ball_size/2 %>px;
          bottom: <%= @ball_position.y - @ball_size/2 %>px;
          width: <%= @ball_size %>px;
          height: <%= @ball_size %>px;
          background-color: white;
        "
      ></div>

      <div
        class="paddle player-1"
        style="
          position:absolute;
          left: <%= @player_1_position - @paddle_size/2 %>px;
          top: <%= @height - @paddle_offset %>px;
          width: <%= @paddle_size %>px;
          height: 20px;
          background-color: white;
        "
      ></div>
      <div
        class="paddle player-2"
        style="
          position:absolute;
          left: <%= @player_1_position - @paddle_size/2 %>px;
          bottom: <%= @height - @paddle_offset %>px;
          width: <%= @paddle_size %>px;
          height: 20px;
          background-color: white;
        "
      ></div>
    </div>
    """
  end

  def mount(_session, socket) do
    {:ok, socket |> new_game() |> schedule_tick()}
  end

  defp new_game(socket) do
    defaults = %{
      score: 0,
      game_state: :playing,
      heading: :stationary,
      pending_headings: %{left: False, right: False},
      ball_size: @ball_size,
      ball_speed: @ball_speed,
      paddle_size: @paddle_size,
      paddle_offset: @paddle_offset,
      width: @width,
      height: @height,
      tick: @tick,
      ball_position: @ball_position,
      player_1_position: @player_1_position,
    }

    new_socket =
      socket
      |> assign(defaults)

    if connected?(new_socket) do
      #some setup
      new_socket
    else
      new_socket
    end
  end

  def handle_event("update_settings", %{"width" => width, "tick" => tick}, socket) do
    {width, ""} = Integer.parse(width)
    {tick, ""} = Integer.parse(tick)

    new_socket =
      socket
      |> update_size(width)
      |> update_tick(tick)

    {:noreply, new_socket}
  end

  def handle_event("new_game", _, socket) do
    {:noreply, new_game(socket)}
  end

  def handle_event("keydown", key, socket) do
    direction = case key do
      "ArrowLeft" -> :left 
      "ArrowRight" -> :right
      _ -> :none
    end
    {:noreply, set_heading(socket, direction)}
  end

  def handle_event("keyup", key, socket) do
    direction = case key do
      "ArrowLeft" -> :left 
      "ArrowRight" -> :right
      _ -> :none
    end
    {:noreply, unset_heading(socket, direction)}
  end

  def handle_info(:tick, socket) do
    new_socket =
      socket
      |> game_loop()
      |> schedule_tick()

    {:noreply, new_socket}
  end

  defp update_tick(socket, tick) when tick <= 1000 and tick >= 50 do
    assign(socket, :tick, tick)
  end

  defp schedule_tick(socket) do
    Process.send_after(self(), :tick, socket.assigns.tick)
    socket
  end

  defp update_size(socket, width) do
    socket
    |> assign(ball_size: width)
  end

  defp set_heading(socket, :none), do: socket
  defp unset_heading(socket, :none), do: socket

  defp set_heading(socket, heading) do
    update(socket, :pending_headings, &(Map.put(&1, heading, True)))
  end
  defp unset_heading(socket, heading) do
    update(socket, :pending_headings, &(Map.put(&1, heading, False)))
  end

  defp next_heading(socket) do
    case socket.assigns.pending_headings do
      %{left: left, right: right} when left == right -> :stationary
      %{left: True, right: False} -> :left
      %{left: False, right: True} -> :right
    end
  end

  defp next_paddle_position(heading, socket) do
    case heading do
      :stationary -> socket.assigns.player_1_position
      :left -> max(socket.assigns.player_1_position - @paddle_speed, 0+@paddle_size/2)
      :right -> min(socket.assigns.player_1_position + @paddle_speed, @width-@paddle_size/2)
    end
  end

  defp bounce_ball(socket) do
  end

  defp get_ball_intersect_bottom(socket) do
    x = socket.assigns.ball_position.x
    y = socket.assigns.ball_position.y
    slope_x = socket.assigns.ball_speed.x
    slope_y = socket.assigns.ball_speed.y
    slope = slope_y / slope_x
    offset = y - slope * x
    (y_min - offset) / slope
  end

  defp get_ball_intersect_top(socket) do
    x = socket.assigns.ball_position.x
    y = socket.assigns.ball_position.y
    slope_x = socket.assigns.ball_speed.x
    slope_y = socket.assigns.ball_speed.y
    slope = slope_y / slope_x
    offset = y - slope * x
    (y_max - offset) / slope
  end


  defp next_ball_position(socket) do
    ball_speed = socket.assigns.ball_speed
    {ball_speed_x, next_x_position} = case socket.assigns.ball_position.x + ball_speed.x do
        position when position < x_min or position > x_max ->
          overshoot = cond do
            position < x_min -> position - x_min
            position > x_max -> x_max - position
          end
          {-ball_speed.x, socket.assigns.ball_position.x - ball_speed.x + overshoot}
        position ->
          {socket.assigns.ball_speed.x, position}
    end
    next_x_position = socket.assigns.ball_position.x + socket.assigns.ball_speed.x
    {gameover, ball_speed_y, next_y_position, points} = case socket.assigns.ball_position.y + ball_speed.y do
        position when position < y_min or position > y_max ->
          {x_intercept, overshoot} = cond do
            position < y_min -> {get_ball_intersect_bottom(socket), position - y_min}
            position > y_max -> {get_ball_intersect_top(socket), y_max - position}
          end
          if abs(x_intercept - socket.assigns.player_1_position) > @paddle_size/2 + @ball_size/2 do
            {true, ball_speed.y, position, 0}
          else
            {false, -ball_speed.y, socket.assigns.ball_position.y - ball_speed.y + overshoot, 1}
          end
        position -> {false, socket.assigns.ball_speed.y, position, 0}
    end
    IO.puts(gameover)
    if gameover do
      game_over(socket)
    else
      socket
      |> update(:ball_position, fn _ -> %{x: next_x_position, y: next_y_position} end)
      |> update(:ball_speed, fn _ -> %{x: ball_speed_x, y: ball_speed_y} end)
      |> update(:score, fn s -> s + points end)
    end
  end

  # defp game_loop(%{assigns: %{pending_headings: %{}} = socket), do: socket

  defp game_loop(socket) do
    if socket.assigns.game_state == :playing do
      heading = next_heading(socket)
      # {row_before, col_before} = coord(socket)
      # maybe_row = row(row_before, heading)
      # maybe_col = col(col_before, heading)
      paddle_position = next_paddle_position(heading, socket)


      socket
      |> next_ball_position()
      |> update(:heading, fn _ -> heading end)
      |> update(:player_1_position, fn _ -> paddle_position end)
    else
      socket
    end
  end


  # def handle_collision(socket, :tail), do: game_over(socket)
  #def handle_collision(socket, :wall), do: wall_bounce(socket)
  # def handle_collision(socket, :paddle), do: paddle_bounce(socket)
  # def handle_collision(socket, :empty), do: socket

  defp game_over(socket), do: assign(socket, :game_state, :over)

  # defp paddle_bounce(socket) do
  #   socket
  #   |> assign(:score, socket.assigns.score + 1)
  #   |> assign(:ball_speed, %{x: @ball_speed.x, y: -@ball_speed.y})
  # end
end
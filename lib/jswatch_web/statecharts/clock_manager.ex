defmodule JswatchWeb.ClockManager do
  use GenServer

  def format_date(date, show, selection) do
    day = if date.day < 10, do: "0#{date.day}", else: "#{date.day}"
    month = ~w[ENE FEB MAR ABR MAY JUN JUL AGO SEP OCT NOV DIC] |> Enum.at(date.month - 1)
    year = date.year - 2000
    {day,month,year} =
      case selection do
        Day -> {(if show, do: day, else: "  "), month, year}
        Month -> {day, (if show, do: month, else: "   "), year}
        _ -> {day, month, (if show, do: year, else: "  ")}
      end
    "#{day}/#{month}/#{year}"
  end

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {_, now} = :calendar.local_time()
    date = Date.utc_today()
    time = Time.from_erl!(now)
    alarm = Time.add(time, 10)
    Process.send_after(self(), :working_working, 1000)
    GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string })
    GenServer.cast(ui, {:set_date_display, format_date(date, true, Day) })
    {:ok, %{ui_pid: ui, time: time, date: date, alarm: alarm, st1: Working, st2: Idle, count: 0, selection: Day, show: true}}
  end

  def handle_info(:working_working, %{ui_pid: ui, time: time, alarm: alarm, st1: Working} = state) do
    Process.send_after(self(), :working_working, 1000)
    time = Time.add(time, 1)
    if time == alarm do
      :gproc.send({:p, :l, :ui_event}, :start_alarm)
    end
    GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string })
    {:noreply, state |> Map.put(:time, time) }
  end

  #Changes state when bottom right button is pressed and date is in Idle
  def handle_info(:bottom_right_pressed, %{ui_pid: ui, date: date, st2: Idle} = state) do
    state = %{
      state
      | st1: Stopped,
      st2: Editing,
      count: 0,
      selection: Day,
      show: false
    }
    Process.send_after(self(), :check_editing_timeout, 250)
    GenServer.cast(ui, {:set_date_display, format_date(date, false, Day)})
    {:no_reply, state}
  end

  def handle_info(:bottom_right_pressed, %{ui_pid: ui, date: date, st2: Editing, count: 0, selection: Day} = state) do
    state = %{
      state
      | count: 0,
        show: true,
        selection: Month
    }
    Process.send_after(self(), :check_editing_timeout, 250)
    GenServer.cast(ui, {:set_date_display, format_date(date, true, Month)})
    {:noreply, state}
  end

  def handle_info(:bottom_right_pressed, %{ui_pid: ui, date: date, st2: Editing, count: 0, selection: Month} = state) do
    state = %{
      state
      | count: 0,
        show: true,
        selection: Year
    }
    Process.send_after(self(), :check_editing_timeout, 250)
    GenServer.cast(ui, {:set_date_display, format_date(date, true, Year)})
    {:noreply, state}
  end

  def handle_info(:bottom_right_pressed, %{ui_pid: ui, date: date, st2: Editing, count: 0, selection: Year} = state) do
    state = %{
      state
      | count: 0,
        show: true,
        selection: Day
    }
    Process.send_after(self(), :check_editing_timeout, 250)
    GenServer.cast(ui, {:set_date_display, format_date(date, true, Day)})
    {:noreply, state}
  end

  def handle_info(:bottom_right_pressed, %{ui_pid: ui, st2: Editing, count: count, show: show, date: date, selection: selection} = state) when count < 20 do
    count = count + 1
    show = not show

    Process.send_after(self(), :check_editing_timeout, 250)
    GenServer.cast(ui, {:set_date_display, format_date(date, show, selection)})
    {:noreply, %{state | count: count, show: show}}
  end

  def handle_info(:bottom_left_pressed, %{ui_pid: ui, st2: Editing, count: 0, selection: Day, date: date} = state) do
    date = Date.add(date.day, 1)
    Process.send_after(self(), :check_editing_timeout, 250)
    GenServer.cast(ui, {:set_date_display, format_date(date, true, Day)})
    {:noreply, %{state | date:  date, show: true}}
  end

  def handle_info(:bottom_left_pressed, %{ui_pid: ui, st2: Editing, count: 0, selection: Month, date: date} = state) do
    {year, month, day} = {date.year, date.month + 1, date.day}
    {:ok, new_date} = Date.new(year + div(month - 1, 12), rem(month - 1, 12) + 1, day)
    date = new_date
    Process.send_after(self(), :check_editing_timeout, 250)
    GenServer.cast(ui, {:set_date_display, format_date(date, true, Month)})
    {:noreply, %{state | date:  date, show: true}}
  end

  def handle_info(:bottom_left_pressed, %{ui_pid: ui, st2: Editing, count: 0, selection: Year, date: date} = state) do
    {:ok, new_date} = Date.new(date.year + 1, date.month, date.day)
    date = new_date
    Process.send_after(self(), :check_editing_timeout, 250)
    GenServer.cast(ui, {:set_date_display, format_date(date, true, Year)})
    {:noreply, %{state | date:  date, show: true}}
  end

  def handle_info(_event, state), do: {:noreply, state}
end

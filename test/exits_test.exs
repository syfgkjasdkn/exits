defmodule ExitsTest do
  use ExUnit.Case

  describe "trapping exits" do
    setup do
      {:ok, pid} = Exits.Trapping.start_link()

      # to check if we lose the state on task exit
      :sys.replace_state(pid, fn state ->
        %{state | state: 10}
      end)

      :erlang.trace(pid, true, [:receive])
      {:ok, pid: pid}
    end

    test "normal", %{pid: pid} do
      send(pid, {:task, fn -> 42 end})

      assert_receive {:trace, ^pid, :receive, {:task, _fun}}
      assert_receive {:trace, ^pid, :receive, {_ref, 42}}
      assert_receive {:trace, ^pid, :receive, {:EXIT, _task_pid, :normal}}
      assert_receive {:trace, ^pid, :receive, {:DOWN, _ref, :process, _task_pid, :normal}}

      assert %Exits.Trapping{state: 10} = :sys.get_state(pid)
    end

    test "crash", %{pid: pid} do
      send(pid, {:task, fn -> raise("oops") end})

      assert_receive {:trace, ^pid, :receive, {:task, _fun}}

      assert_receive {:trace, ^pid, :receive,
                      {:EXIT, _task_pid, {%RuntimeError{message: "oops"}, _stacktrace}}}

      assert_receive {:trace, ^pid, :receive,
                      {:DOWN, _ref, :process, _task_pid,
                       {%RuntimeError{message: "oops"}, _stacktrace}}}

      assert %Exits.Trapping{state: 10} = :sys.get_state(pid)
    end
  end
end

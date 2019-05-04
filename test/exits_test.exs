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
      %Task{ref: ref, pid: task_pid} = GenServer.call(pid, {:task, fn -> 42 end})

      assert_receive {:trace, ^pid, :receive, {:"$gen_call", _from, {:task, _fun}}}
      assert_receive {:trace, ^pid, :receive, {^ref, 42}}
      assert_receive {:trace, ^pid, :receive, {:EXIT, ^task_pid, :normal}}
      assert_receive {:trace, ^pid, :receive, {:DOWN, ^ref, :process, ^task_pid, :normal}}

      refute_receive _anything_else

      assert %Exits.Trapping{state: 10} = :sys.get_state(pid)
    end

    test "crash", %{pid: pid} do
      %Task{ref: ref, pid: task_pid} = GenServer.call(pid, {:task, fn -> raise("oops") end})

      assert_receive {:trace, ^pid, :receive, {:"$gen_call", _from, {:task, _fun}}}

      assert_receive {:trace, ^pid, :receive,
                      {:EXIT, ^task_pid, {%RuntimeError{message: "oops"}, _stacktrace}}}

      assert_receive {:trace, ^pid, :receive,
                      {:DOWN, ^ref, :process, ^task_pid,
                       {%RuntimeError{message: "oops"}, _stacktrace}}}

      refute_receive _anything_else

      assert %Exits.Trapping{state: 10} = :sys.get_state(pid)
    end
  end

  describe "supervised" do
    setup do
      {:ok, pid} = Exits.Supervised.start_link()

      # to check if we lose the state on task exit
      :sys.replace_state(pid, fn state ->
        %{state | state: 10}
      end)

      :erlang.trace(pid, true, [:receive])
      {:ok, pid: pid}
    end

    test "normal", %{pid: pid} do
      %Task{ref: ref, pid: task_pid} = GenServer.call(pid, {:async, fn -> 42 end})

      assert_receive {:trace, ^pid, :receive, {:"$gen_call", _from, {:async, _fun}}}
      assert_receive {:trace, ^pid, :receive, {_ref, {:ok, ^task_pid}}}
      assert_receive {:trace, ^pid, :receive, {^ref, 42}}
      assert_receive {:trace, ^pid, :receive, {:DOWN, ^ref, :process, ^task_pid, :normal}}

      refute_receive _anything_else

      assert %Exits.Supervised{state: 10} = :sys.get_state(pid)
    end

    test "crash", %{pid: pid} do
      Process.flag(:trap_exit, true)

      %Task{pid: task_pid} = GenServer.call(pid, {:async, fn -> raise("oops") end})

      assert_receive {:trace, ^pid, :receive, {:"$gen_call", _from, {:async, _fun}}}
      assert_receive {:trace, ^pid, :receive, {_ref, {:ok, ^task_pid}}}
      assert_receive {:EXIT, ^pid, {%RuntimeError{message: "oops"}, _stacktrace}}

      refute_receive _anything_else

      refute Process.alive?(pid)

      Process.flag(:trap_exit, false)
    end

    test "normal nolink", %{pid: pid} do
      %Task{ref: ref, pid: task_pid} = GenServer.call(pid, {:async_nolink, fn -> 42 end})

      assert_receive {:trace, ^pid, :receive, {:"$gen_call", _from, {:async_nolink, _fun}}}
      assert_receive {:trace, ^pid, :receive, {_ref, {:ok, ^task_pid}}}
      assert_receive {:trace, ^pid, :receive, {^ref, 42}}
      assert_receive {:trace, ^pid, :receive, {:DOWN, ^ref, :process, ^task_pid, :normal}}

      refute_receive _anything_else

      assert %Exits.Supervised{state: 10} = :sys.get_state(pid)
    end

    test "crash nolink", %{pid: pid} do
      %Task{ref: ref, pid: task_pid} =
        GenServer.call(pid, {:async_nolink, fn -> raise("oops") end})

      assert_receive {:trace, ^pid, :receive, {:"$gen_call", _from, {:async_nolink, _fun}}}
      assert_receive {:trace, ^pid, :receive, {_ref, {:ok, ^task_pid}}}

      assert_receive {:trace, ^pid, :receive,
                      {:DOWN, ^ref, :process, ^task_pid,
                       {%RuntimeError{message: "oops"}, _stacktrace}}}

      refute_receive _anything_else

      assert %Exits.Supervised{state: 10} = :sys.get_state(pid)
    end
  end
end

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

    test "normal stream", %{pid: pid} do
      stream = GenServer.call(pid, {:stream, fn i -> i * 2 end, [1, 2, 3, 4]})
      assert [2, 4, 6, 8] == Enum.map(stream, fn {:ok, i} -> i end)

      assert_receive {:trace, ^pid, :receive, {:"$gen_call", _from, {:stream, _fun, _enum}}}

      refute_receive _anything_else

      assert %Exits.Trapping{state: 10} = :sys.get_state(pid)
    end

    # TODO finish
    # test "crash stream", %{pid: pid} do
    #   stream =
    #     GenServer.call(
    #       pid,
    #       {:stream,
    #        fn i ->
    #          if rem(i, 2) == 0 do
    #            raise("oops")
    #          else
    #            i * 2
    #          end
    #        end, [1, 2, 3, 4]}
    #     )

    #   assert [2, 4, 6, 8] == Enum.to_list(stream)

    #   assert_receive {:trace, ^pid, :receive, {:"$gen_call", _from, {:stream, _fun, _enum}}}

    #   refute_receive _anything_else

    #   assert %Exits.Trapping{state: 10} = :sys.get_state(pid)
    # end
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

    test "normal stream", %{pid: pid} do
      stream = GenServer.call(pid, {:async_stream, fn i -> i * 2 end, [1, 2, 3, 4]})

      assert [2, 4, 6, 8] == Enum.map(stream, fn {:ok, i} -> i end)

      assert_receive {:trace, ^pid, :receive, {:"$gen_call", _from, {:async_stream, _fun, _enum}}}

      refute_receive _anything_else

      assert %Exits.Supervised{state: 10} = :sys.get_state(pid)
    end

    test "crash stream", %{pid: pid} do
      Process.flag(:trap_exit, true)

      stream =
        GenServer.call(
          pid,
          {:async_stream,
           fn i ->
             if rem(i, 2) == 0 do
               raise("oops")
             else
               i * 2
             end
           end, [1, 2, 3, 4]}
        )

      assert [
               {:ok, 2},
               {:exit, {%RuntimeError{message: "oops"}, _stacktrace1}},
               {:ok, 6},
               {:exit, {%RuntimeError{message: "oops"}, _stacktrace2}}
             ] = Enum.to_list(stream)

      assert_receive {:trace, ^pid, :receive, {:"$gen_call", _from, {:async_stream, _fun, _enum}}}

      refute_receive _anything_else

      Process.flag(:trap_exit, false)
    end

    test "normal stream nolink", %{pid: pid} do
      stream = GenServer.call(pid, {:async_stream_nolink, fn i -> i * 2 end, [1, 2, 3, 4]})

      assert [2, 4, 6, 8] == Enum.map(stream, fn {:ok, i} -> i end)

      assert_receive {:trace, ^pid, :receive,
                      {:"$gen_call", _from, {:async_stream_nolink, _fun, _enum}}}

      refute_receive _anything_else

      assert %Exits.Supervised{state: 10} = :sys.get_state(pid)
    end

    test "crash stream nolink", %{pid: pid} do
      stream =
        GenServer.call(
          pid,
          {:async_stream_nolink,
           fn i ->
             if rem(i, 2) == 0 do
               raise("oops")
             else
               i * 2
             end
           end, [1, 2, 3, 4]}
        )

      assert [
               {:ok, 2},
               {:exit, {%RuntimeError{message: "oops"}, _stacktrace1}},
               {:ok, 6},
               {:exit, {%RuntimeError{message: "oops"}, _stacktrace2}}
             ] = Enum.to_list(stream)

      assert_receive {:trace, ^pid, :receive,
                      {:"$gen_call", _from, {:async_stream_nolink, _fun, _enum}}}

      refute_receive _anything_else
    end
  end
end

defmodule BgpTable.Consumer do

  use GenServer
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: BgpTable.Consumer])
  end

  def init(:ok) do
    Logger.info("Starting rabbitmq listener")
    :ets.new(:prefix_table, [:named_table, :set])
    :ets.new(:peer_table, [:named_table, :set])
    {:ok, connection} = AMQP.Connection.open()
    {:ok, channel} = AMQP.Channel.open(connection)
    :ok = AMQP.Exchange.declare(channel, "pmacct", :direct)
    {:ok, %{queue: queue_name}} = AMQP.Queue.declare(channel, "", exclusive: true)
    :ok = AMQP.Queue.bind(channel, queue_name, "pmacct", routing_key: "routes")
    {:ok, _} = AMQP.Basic.consume(channel, queue_name, nil, no_ack: true)
    {:ok, nil}
  end


  def handle_info({:basic_deliver, payload, _}, state) do
    payload |> JSON.decode!
    |> classify_event
    |> record_event
    Logger.debug("Got event #{payload}")
    {:noreply, state}
  end

  def handle_info(data, state) do
    {:noreply, state}
  end

  defp record_event({:update, data}) do
    case :ets.lookup(:prefix_table, data["ip_prefix"]) do
      [{_, result}] -> :ets.insert(:prefix_table, {data["ip_prefix"], result ++ [to_path(data)]})
      []            -> :ets.insert(:prefix_table, {data["ip_prefix"], [to_path(data)]})
    end
  end

  defp record_event({:unknown, _}) do
    Logger.error("Got an unknown event")
  end

  defp record_event({:delete, data}) do
    new_paths = []
    {prefix, path} = to_path(data)
    case :ets.lookup(:prefix_table, prefix) do
      {_prefix, current_paths} -> new_paths = delete_path(current_paths, path, [])
      _                        -> nil
    end
    case new_paths do
      [h|t] -> :ets.insert(:prefix_table, {prefix, new_paths})
      []    -> :ets.delete(:prefix_table, prefix)
    end
  end

  defp delete_path([h|t], path, acc) do
    IO.puts(path, acc)
    cond do
      path == h -> [acc|t]
      true      -> delete_path(t, path, acc)
    end
  end

  defp delete_path([], path, acc) do
    acc
  end

  defp to_path(data) do
    path = %{
      router: data["peer_ip_src"],
      community: data["comms"],
      next_hop: data["bgp_nexthop"],
      as_path: data["as_path"],
    }
    {data["ip_prefix"], path}
  end

  defp classify_event(msg) do
    {event, msg} = Map.pop(msg, "event_type")
    case event do
      "log" ->
        case msg["log_type"] do
          "update"   -> {:update, msg}
          "withdraw" -> {:delete, msg}
          "delete"   -> {:delete, msg}
          _          -> {:unknown, msg}
        end
      _  -> {:unknown, msg}
    end
  end

end


defmodule BgpTable.LookupTable.Prefix do

  use GenServer

  alias BgpTable.Parser, as: Parser

  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def get_prefix(prefix) do
    case :ets.lookup(:prefix_etable, prefix) do
      []                  -> :no_such_route
      [{_prefix, result}] -> {:ok, result}
    end
  end

  def process(payload) do
    GenServer.cast(__MODULE__, payload)
    payload
  end


  def init(:ok) do
    :ets.new(:prefix_table, [:named_table, :set])
    Logger.info("Started loop")
    {:ok, nil}
  end

  def handle_call({:get_prefix}) do
    nil
  end

  def handle_cast({:update, data}, _) do
    {prefix, path} = Parser.to_prefix_object(data)
    Logger.debug("Updating #{inspect data}")
    case :ets.lookup(:prefix_table, prefix) do
      [{_, result}] -> :ets.insert(:prefix_table, {prefix, result ++ [path]})
      []            -> :ets.insert(:prefix_table, {prefix, [path]})
    end
    Logger.debug("Object updated successfully")
    {:noreply, nil}
  end
  def handle_cast({:delete, data}, _) do
    Logger.debug("Deleting object #{inspect data}")
    {prefix, path} = Parser.to_prefix_object(data)
    table_data = :ets.lookup(:prefix_table, prefix)
    case Parser.delete_path(table_data, path) do
      :empty   -> :ets.delete(:prefix_table, prefix)
      [h|t]    -> :ets.insert(:prefix_table, {prefix, [h|t]})
      :nomatch -> Logger.error("Trying to delete a none existing object")
    end
    {:noreply, nil}
  end
  def handle_cast({:unknown, data}, _) do
    Logger.error("Receivd unknown message #{inspect data}")
    {:noreply, nil}
  end

end



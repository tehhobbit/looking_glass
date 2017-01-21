
defmodule BgpTable.Lookup do

  def get_prefix(prefix) do
    case :ets.lookup(:bgp_table, prefix) do
      []                  -> :no_such_route
      [{_prefix, result}] -> {:ok, result}
    end
  end
end


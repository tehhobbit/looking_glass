defmodule BgpTable.Parser do
  def to_prefix_object(data) do
    path = %{
      router: data["peer_ip_src"],
      community: data["comms"],
      next_hop: data["bgp_nexthop"],
      as_path: data["as_path"],
    }
    {data["ip_prefix"], path}
  end

  def delete_path([h|t], path, acc) do
    cond do
      path == h -> delete_path([], path, [acc|t])
      true      -> delete_path(t, path, [h|acc])
    end
  end

  def delete_path([], path, []) do
    :empty
  end

  def delete_path([], _, acc) do
    acc
  end
end

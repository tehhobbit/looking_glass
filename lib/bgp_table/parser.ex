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
end

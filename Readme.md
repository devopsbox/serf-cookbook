## Serf

  - http://www.serfdom.io/


## Example config file


    node.default[:serf][:version]          = '0.2.1'
    node.default[:serf][:encrypt_key]      = "I3vDELDtXpWBIabHF5IWiw=="
    node.default[:serf][:role]             = "base"
    node.default[:serf][:encrypt_rpc_port] = 7374
    node.default[:serf][:rpc_addr]         = node[:ipaddress] + ":#{node.default[:serf][:encrypt_rpc_port]}"
    node.default[:serf][:start_join]       = ["123.123.123.123", "123.123.123.124"]
    node.default[:serf][:event_handlers]   = [
      "/etc/serf/handlers/hostsfile.rb",
      "user:deploy=/etc/serf/handlers/deploy.sh"
    ]

    include_recipe "serf"

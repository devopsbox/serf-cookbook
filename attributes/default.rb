node.default[:serf][:version]          = '0.2.1'
node.default[:serf][:encrypt_key]      = "XXXXXXXXXXXXXX"
node.default[:serf][:role]             = "base"
node.default[:serf][:encrypt_rpc_port] = 7374
node.default[:serf][:rpc_addr]         = node[:ipaddress] + ":#{node.default[:serf][:encrypt_rpc_port]}"
node.default[:serf][:start_join]       = []
node.default[:serf][:event_handlers]   = []
node.default[:serf][:url]              = "https://dl.bintray.com/mitchellh/serf/#{node[:serf][:version]}_linux_amd64.zip"

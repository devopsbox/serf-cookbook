
node.default[:serf][:version]          = '0.2.1'
node.default[:serf][:encrypt_key]      = "I3vDELDtXpWBIabHF5IWiw=="
node.default[:serf][:role]             = "base"
node.default[:serf][:encrypt_rpc_port] = 7374
node.default[:serf][:rpc_addr]         = node[:ipaddress] + ":#{node.default[:serf][:encrypt_rpc_port]}"
node.default[:serf][:start_join]       = ["192.241.144.49", "192.241.146.150"]
node.default[:serf][:event_handlers]   = [
  "/etc/serf/handlers/hostsfile.rb",
  "user:deploy=/etc/serf/handlers/deploy.sh"
]


version  = node[:serf][:version]
filename = "#{version}_linux_amd64.zip"
url      = "https://dl.bintray.com/mitchellh/serf/#{filename}"


package "unzip" do
  action :install
end

bash "install serf #{version}" do
  code "cd /tmp && \
    wget #{url} && \
    unzip -o #{filename} && \
    mv serf /usr/local/bin/ && \
    rm #{filename}"
  not_if "test -e /usr/local/bin/serf && serf version|grep #{version}"
end

include_recipe 'serf::config'

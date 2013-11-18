## http://www.serfdom.io/docs/agent/options.html

module Serf
  class ConfigGenerator
    TEMPLATE = {
      "role"           => "XXX",
      "node_name"      => "XXX",
      "role"           => "XXX",
      "bind_addr"      => "XXX",
      "rpc_addr"       => "XXX",
      "encrypt_key"    => "XXX",
      "log_level"      => "info",
      "protocol"       => 1,
      "start_join"     => [],
      "event_handlers" => []
    }

    def self.generate(node)
      template                   = TEMPLATE.clone

      template["node_name"]      = node[:hostname]
      template["bind_addr"]      = node[:ipaddress]

      template["role"]           = node[:serf][:role]
      template["rpc_addr"]       = node[:serf][:rpc_addr]
      template["encrypt_key"]    = node[:serf][:encrypt_key]
      template["start_join"]     = node[:serf][:start_join]
      template["event_handlers"] = node[:serf][:event_handlers]

      JSON.pretty_generate(template)
    end
  end
end


directory "/etc/serf" do
  action :create
end

directory "/etc/serf/handlers" do
  action :create
end

file "/etc/serf/serf.conf" do
  content Serf::ConfigGenerator.generate(node)
end


%w(hostsfile.rb).each do |event_handler|
  template "/etc/serf/handlers/#{event_handler}" do
    source "handlers/#{event_handler}"
    mode 00755
  end
end

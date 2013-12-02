package "unzip"

ark 'serf' do
  url node[:serf][:url]
  version node[:serf][:version]
  path '/usr/local/bin'
  creates 'serf'
  action :cherry_pick
end

include_recipe 'serf::config'

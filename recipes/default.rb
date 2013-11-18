
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

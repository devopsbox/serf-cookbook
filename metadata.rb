name              "serf"
maintainer        "Roman Heinrich"
maintainer_email  "roman.heinrich@gmail.com"
license           "MIT"
description       "A cookbookbook for Serf (serfdom.io)"
version           "0.1.0"

%w{ debian ubuntu }.each do |os|
  supports os
end

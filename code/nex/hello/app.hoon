::  hello nexus: placeholder for the hatchery desk
::
/&  man  ../../man/hello/readme.md
^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  %+  spin:loader  ball
  :~  (manifest:loader 0)
      [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'hello'] ['description' s+'hatchery placeholder']])]]
      [%over %& [/ %'README.md'] [[/ %mime] man]]
  ==
++  on-file
  |=  [=rail:tarball =blot:tarball]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  stay:m
--

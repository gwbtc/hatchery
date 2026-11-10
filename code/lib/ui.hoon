::  ui: serving the shared web components in /lib/ui.
::
|%
::  +block: a classic script in its own block, so its top-level consts
::  cannot collide with another's when several are served as one file.
::
++  block
  |=  =mime
  ^-  @t
  (rap 3 ~['{' 10 q.q.mime 10 '}' 10])
::  +bundle: several scripts as one javascript file, so a page makes one
::  request for all its components.
::
++  bundle
  |=  parts=(list mime)
  ^-  mime
  [/application/javascript (as-octs:mimes:html (rap 3 (turn parts block)))]
--

RBMK
====
[//]: # (DESCRIPTION START)
This is a rather simple Ruby LDAP server that proxies operations upstream but
at the same time provides a facility to invoke your code at certain points in
the operation runtime. This may help to accomodate for some clients that
are not smart enough to implement the logic you need themselves.
LDAP is very rigid and static in its nature and although OpenLDAP provides some
very helpful overlays, it is far from enough.
[//]: # (DESCRIPTION STOP)

☢ CAUTION ☢
-----------
Like its name suggests, `rbmk` is somewhat powerful, but is not very stable.
Expect random meltdowns! Please, **NEVER** run it as superuser. LDAP gems
that it uses are surprisingly feature-rich, but are not quite polished yet.
This user does not have the time to rewrite them and does not consider it
a huge problem. Remember, the best architecture is not the one that never fails,
but is instead the one that can handle failures gracefully.

LIMITATIONS
-----------
* This proxy is read-only, by design.
* This script does not detach from its terminal, again by design.
* Only simple binds, at least until I actually need SASL myself.
* No TLS for now, but maybe someday.
* Only tested with MRI 2.2, but will likely work with anything 1.9+.
* Well, maybe not anything, as it uses [ruby-ldap](https://github.com/bearded/ruby-ldap) (a C extension).

INSTALL
-------
`gem install rbmk`, simple as that.

RUN
---
As this script is not a daemon, you have two easy options besides anything
you may invent yourself:
* use any supervisor that are plenty nowadays: `supervisord`, `bluepill` etc.
* or just run it inside a `tmux` session and leave it there.

USAGE
-----
`rbmk FILENAME`, where *FILENAME* is a configuration file.

CONFIGURATION
-------------
Upon its invocation `rbmk` evals its first argument and thus is configured
by your Ruby code inside that file. Please refer to `examples/rbmk.rb` for
an example configuration file.

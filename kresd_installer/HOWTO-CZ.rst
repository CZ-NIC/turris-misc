Instalace testovací verze služby Knot DNS Resolver
===================================================

Pokud nám chcete pomoci s testováním aplikace Knot DNS Resolver, připravili jsme pro Vás sadu balíků, které můžete do routeru Turris jednoduše doinstalovat. Aplikace Knot DNS Resolver je cachující DNS resolver, který by měl v budoucnu na routerech Turris nahradit službu Unbound.

**UPOZORNĚNÍ**: Současná verze aplikace Knot DNS Resolver pro Turris zatím nepodporuje ověřování pomocí technologie DNSSEC, klienti na LAN používající Turris jako DNS resolver tedy nebudou chráněni před podvržením DNS záznamů. Pro resolving na samotném routeru (tedy např. při stahování aktualizací nebo komunikaci se centrálními servery Turris) však bude stále používán resolver Unbound, který DNSSEC validaci provádí. V instalaci pokračujte pouze v případě, že rozumíte případným rizikům.

Postup instalace
----------------

K jednoduché instalaci Knot Resolveru v současné době slouží skript, který naleznete v `repozitáři turris/misc <https://github.com/CZ-NIC/turris-misc/tree/master/kresd_installer>`_ na GitLabu CZ.NIC Labs. Tento skript provede všechny úkony, které jsou nezbytné pro souběžné provozování resolveru Unbound pro překlad DNS záznamů na routeru, a Knot Resolveru pro klienty připojené na síti LAN.

Po přihlášení do konzole nejprve stáhneme instalační skript::

    wget https://gitlab.labs.nic.cz/turris/misc/raw/master/kresd_installer/kresd_installer.sh

Skript nastavíme jako spustitelný::

    chmod +x kresd_installer.sh

A skript spustíme::

    ./kresd_installer.sh

Po spuštění se zobrazí informační text, který je nutné odsouhlasit. Následně proběhne automatická instalace, v průběhu níž budete vyzváni k zadání IP adresy zařízení – tzn. adresy, pod kterou je zařízení dostupné na síti LAN. Ta by měla být ale ve většině konfigurací sítě správně detekována automaticky.

V případě, že chcete sledovat podrobný výpis příkazů, které se během instalace spouštějí nebo pokud automatická instalace selhává, je vhodné spustit instalátor s flagem ``-d``. V tomto případě je potřeba potvrdit provedení každého kroku stiskem klávesy (např. ``Enter``).

Odinstalace
-----------

Odinstalování je nutné provést ručně. To spočívá v odstranění firewallového pravidla, které zajišťuje přesměrování příchozího provozu na LAN z portu 53 na port 5353 (buď přes rozhraní LuCI, ruční editací souboru ``/etc/config/firewall``) nebo pomocí příkazu ``uci delete`` – pravidlo lze identifikovat podle položky ``name`` s hodnotou *knot-resolver redirect*), a odstraněním doinstalovaných balíčků (pokud nemají v systému závislosti).

Několik balíků v systému závislosti nemá (jsou z repozitáře vývojové verze), ty můžete odstranit rovnou::

    opkg remove knot-libdnssec knot-resolver libuv luajit

Další však závislosti mít mohou (``knot-libknot``, ``libgnutls``, ``libnettle``, ``jansson``, ``libgmp`` a ``liburcu``), pokud tomu tak je, odstraňte je pomocí ``opkg --force-depends ...`` a poté je nainstalujte ze standardního repozitáře balíčků pomocí ``opkg install ...``.


Další informace
---------------

Parametry pro jednotlivé instance služby ``kresd`` je možné předávat prostřednictvím voleb konfiguračního souboru v syntaxi UCI, umístěném v ``/etc/config/kresd`` (výchozí konfigurační soubor je možné nalézt v `repozitáři s balíčky pro Turris OS <https://gitlab.labs.nic.cz/turris/turris-os-packages/blob/test/net/knot-resolver/files/kresd.config>`_). Každá sekce ``config kresd`` zde představuje jednu instanci služby ``kresd``, která bude při startu služby ``kresd`` spuštěna. Názvy jednotlivých voleb odpovídají flagům předávaným daemonu ``kresd``, kromě voleb ``log_stderr`` a ``log_stdout`` – ty umožňují přesměrovat standardní výstup (resp. chybový výstup) do syslogu. Tyto volby (pozn.: v případě jejich úpravy je potřeba službu ``kresd`` restartovat – jen reload nestačí) je vhodné zapnout společně s volbou ``verbose`` v případě, že při testování narazíte na problémy.

Kompletní oficiální dokumentaci aplikace Knot DNS Resolver naleznete na Read the Docs: http://knot-resolver.readthedocs.org/en/latest/

V případě, že během provozu narazíte na problémy, můžete je nahlásit prostřednictvím `GitLabu <https://gitlab.labs.nic.cz/knot/resolver/issues>`_ nebo `GitHubu <https://github.com/CZ-NIC/knot-resolver/issues>`_.

include:
  - bind

habind.bind-service:
  service.running:
    - name: named
    - enable: True
    - reload: True
    - watch: {% for dc in salt['pillar.get']('habind:dcs',[]) %}
      - file: /var/named/{{ dc }}.ha.zone{% set cnames = salt['pillar.get']('habind:cnames','cnames') %}
      - file: /var/named/{{ cnames }}.ha-{{ dc }}view{% endfor %}
      - file: /etc/named.conf

habind.bind-data:
  file.directory:
    - name: /var/named
    - user: named
    - group: named
    - mode: 755

habind.bind-config:
  file.managed:
    - name: /etc/named.conf
    - template: jinja
    - source: salt://habind/templates/named.conf
    - user: root
    - group: root
    - mode: 644

habind.ha-zone:
  file.managed:
    - name: /var/named/ha.zone
    - template: jinja
    - source: salt://habind/templates/ha.zone
    - user: named
    - group: named
    - mode: 644

{% set cnames = salt['pillar.get']('habind:cnames','cnames') -%}
{% set reverse_zone_class = salt['pillar.get']('habind:reverse_zone_class','C') -%}

{# this for loop covers extends to bottom of file -#}
{% for dc in salt['pillar.get']('habind:dcs',[]) -%}
{# e.g. 'alpha' -#}

{% set forward_octets = salt['pillar.get']('habind:map:{0}:forward_octets'.format(dc),'') -%}
{# e.g. '10.18.0.0' -#}
habind.{{ dc }}-zone:
  file.managed:
    - name: /var/named/{{ dc }}.ha.zone
    - template: jinja
    - source: salt://habind/templates/forward.ha.zone
    - user: named
    - group: named
    - mode: 644
    - defaults:
      forward_zone: "{{ dc }}.ha"
      forward_octets: "{{ forward_octets }}"
{% set reverse_octets = salt['ipv4_manip.reverse'](forward_octets) -%}
{# e.g. '0.0.18.10' -#}
{% set back_octets = salt['pillar.get']('habind:back_octets',{}).items() -%}
{# e.g. [('foo','83.10'),('bar','83.11')] -#}
{% set reverse_subnets = [] -%}
{% set exclude_reverse_subnets = [] -%}
{% for exclude in salt['pillar.get']('habind:exclude_reverse_subnets',[]) -%}{# e.g. '82.0' #}
{%   do exclude_reverse_subnets.append(salt['ipv4_manip.reverse_zone'](salt['ipv4_manip.add'](forward_octets,exclude),zone_class=reverse_zone_class)) -%}
{% endfor -%}{# e.g. add('10.18.0.0','82.0') -> '10.18.82.0', reverse_zone('10.18.82.0',"C") -> '82.18.10', exclude_reverse_subnets = ['82.18.10'] #}

{% for back_octet in back_octets -%}
{# e.g. [('foo','83.10'),('bar','83.11')] -#}
{% set back_octet_reverse_zone = salt['ipv4_manip.reverse_zone'](salt['ipv4_manip.add'](forward_octets,back_octet[1]),zone_class=reverse_zone_class) -%}
{% if back_octet_reverse_zone not in exclude_reverse_subnets and back_octet_reverse_zone not in reverse_subnets-%}
{%   do reverse_subnets.append(back_octet_reverse_zone)-%}
{% endif -%}
{% endfor -%}
{% for roundrobin, octetslist in salt['pillar.get']('habind:roundrobins',{}).items() -%}
{% for octets in octetslist -%}
{% set roundrobin_octets_str = octets|string -%}
{% set roundrobin_octets_reverse_zone = salt['ipv4_manip.reverse_zone'](salt['ipv4_manip.add'](forward_octets,roundrobin_octets_str),zone_class=reverse_zone_class) -%}
{% if roundrobin_octets_reverse_zone not in exclude_reverse_subnets and roundrobin_octets_reverse_zone not in reverse_subnets -%}
{% do reverse_subnets.append(roundrobin_octets_reverse_zone) -%}
{% endif -%}
{% endfor -%}
{% endfor -%}

{% for reverse_zone in reverse_subnets -%}
habind.{{ reverse_zone }}.{{ dc }}-zone-reverse:
  file.managed:
    - name: /var/named/{{ reverse_zone }}.in-addr.arpa
    - template: jinja
    - source: salt://habind/templates/reverse.in-addr.arpa
    - user: named
    - group: named
    - mode: 644
    - defaults:
        forward_zone: "{{ dc }}.ha"
        forward_octets: "{{ forward_octets }}"
        reverse_zone: "{{ reverse_zone }}"
{% endfor -%}

habind.{{ cnames }}.ha-{{ dc }}view:
  file.managed:
    - name: /var/named/{{ cnames }}.ha-{{ dc }}view
    - template: jinja
    - source: salt://habind/templates/cnames.ha-dcview
    - user: named
    - group: named
    - mode: 644
    - defaults:
        forward_zone: "{{ dc }}.ha"
{% endfor -%}

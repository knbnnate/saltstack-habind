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
{% for dc in salt['pillar.get']('habind:dcs',[]) -%}
{% set forward_octets = salt['pillar.get']('habind:map:{0}:forward_octets'.format(dc),'') -%}
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

{% set reverse_octets = salt['pillar.get']('habind:map:{0}:reverse_octets'.format(dc),'') -%}
{% set back_octets = salt['pillar.get']('habind:back_octets',{}).items() -%}
{% set reverse_subnets = [] -%}
{% set exclude_reverse_subnets = salt['pillar.get']('habind:exclude_reverse_subnets',[]) -%}
{% for back_octet in back_octets -%}
{% set back_octet_subnet = back_octet[1].split(".")[0] -%}
{% if back_octet_subnet not in exclude_reverse_subnets and back_octet_subnet not in reverse_subnets-%}
{%   do reverse_subnets.append(back_octet_subnet)-%}
{% endif -%}
{% endfor -%}
{% for roundrobin, octetslist in salt['pillar.get']('habind:roundrobins',{}).items() -%}
{% for octets in octetslist -%}
{% set roundrobin_octets_str = octets|string -%}
{% set roundrobin_octets_subnet = roundrobin_octets_str.split('.')[0] -%}
{% if roundrobin_octets_subnet not in exclude_reverse_subnets and roundrobin_octets_subnet not in reverse_subnets -%}
{% do reverse_subnets.append(roundrobin_octets_subnet) -%}
{% endif -%}
{% endfor -%}
{% endfor -%}


{% for subnet in reverse_subnets -%}
habind.{{ subnet }}.{{ dc }}-zone-reverse:
  file.managed:
    - name: /var/named/{{ subnet }}.{{ reverse_octets }}.in-addr.arpa
    - template: jinja
    - source: salt://habind/templates/reverse.in-addr.arpa
    - user: named
    - group: named
    - mode: 644
    - defaults:
        forward_zone: "{{ dc }}.ha"
        reverse_octets: "{{ subnet }}.{{ reverse_octets }}"
        reverse_subnet: "{{ subnet }}"
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

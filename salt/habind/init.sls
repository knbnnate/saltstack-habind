include:
  - bind

habind.bind-service:
  service.running:
    - name: named
    - enable: True
    - reload: True
    - watch: {% for dc in salt['pillar.get']('habind:dcs',['alpha']) %}
      - file: /var/named/{{ dc }}.ha.zone{% set reverse_octets = salt['pillar.get']('habind:map:{0}:reverse_octets'.format(dc),'168.192') %}
      - file: /var/named/{{ reverse_octets }}.in-addr.arpa{% set cnames = salt['pillar.get']('habind:cnames','cnames') %}
      - file: /var/named/{{ cnames }}.ha-{{ dc }}view{% endfor %}
      - file: /etc/named.conf

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
{% for dc in salt['pillar.get']('habind:dcs',['alpha']) -%}
{% set forward_octets = salt['pillar.get']('habind:map:{0}:forward_octets'.format(dc),'192.168') -%}
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

{% set reverse_octets = salt['pillar.get']('habind:map:{0}:reverse_octets'.format(dc),'168.192') -%}
habind.{{ dc }}-zone-reverse:
  file.managed:
    - name: /var/named/{{ reverse_octets }}.in-addr.arpa
    - template: jinja
    - source: salt://habind/templates/reverse.in-addr.arpa
    - user: named
    - group: named
    - mode: 644
    - defaults:
        forward_zone: "{{ dc }}.ha"
        reverse_octets: "{{ reverse_octets }}"

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

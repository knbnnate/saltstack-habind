"""
This module provides utility functions for working with IPv4 addresses in ways convenient for managing DNS servers across aribitrary scopes.

Some example inputs and outputs:

                     reverse("255.128.63.16"):                       16.63.128.255
                reverse_zone("255.128.63.16"):                        255.128.63.0
            reverse_zone("255.128.63.16","b"):                         255.128.0.0
 reverse_zone("255.128.63.16",zone_class="a"):                           255.0.0.0
            reverse_zone("255.128.63.16","C"):                        255.128.63.0
                add("10.10.10.0","0.0.10.20"):                         10.10.20.20
               sub("10.10.20.20","0.0.10.20"):                          10.10.10.0
                 mod("10.10.20.20","0.0.1.0"):                            0.0.0.20
               shift("10.10.20.20","0.0.1.0"):                          10.10.20.0
                mod("10.10.20.20","0.0.16.0"):                            0.0.4.20
              shift("10.10.20.20","0.0.16.0"):                          10.10.16.0
                mod("10.10.20.20","0.16.0.0"):                          0.10.20.20
              shift("10.10.20.20","0.16.0.0"):                            10.0.0.0
                    add("10.10.10.0","10.20"):                         10.10.20.20
                      add("10.10.10.0",10.20):                          10.10.20.2

Note that when IP segments with trailing zeroes can be interpreted as floats, the integrity of the operations is compromised.
Be explicit that such segments are strings when storing them e.g. in pillar.

"""
# private ipv4 conversion towards int
def _ipv4_2_hex(ipv4_str):
  return "".join(["{0:02x}".format(int(octet)) for octet in ipv4_str.split(".")])
def _hex_2_int(hex_str):
  return int("0x{0}".format(hex_str),16)
def _ipv4_2_int(ipv4_str):
  return _hex_2_int(_ipv4_2_hex(ipv4_str))

# private ipv4 conversion from int
def _int_2_hex(ipv4_int):
  return "{0:08x}".format(ipv4_int)
def _hex_2_ipv4(hex_str):
  return ".".join(["{0:d}".format(int(octet,16)) for octet in [hex_str[x:x+2] for x in [0,2,4,6]]])
def _int_2_ipv4(ipv4_int):
  return _hex_2_ipv4(_int_2_hex(ipv4_int))

# exposed
def reverse(ipv4_str):
  '''
  A function to reverse the octets of an IPv4 address, e.g. to determine an in-addr.arpa zone entry.

  CLI Example::

      salt '*' ipv4_manip.reverse 255.128.63.16
    
  '''
  return ".".join(str(ipv4_str).split(".")[::-1])

def add(ip_a,ip_b):
  '''
  A function to add together two IPv4 addressess as if they were integers.

  CLI Example::

      salt '*' ipv4_manip.add 10.10.10.0 0.0.10.20
  '''
  return _int_2_ipv4(_ipv4_2_int(str(ip_a))+_ipv4_2_int(str(ip_b)))

def sub(ip_a,ip_b):
  '''
  A function to subtract an IPv4 address from another as if they were integers.

  CLI Example::

      salt '*' ipv4_manip.sub 10.10.20.20 0.0.10.20
  '''
  return _int_2_ipv4(_ipv4_2_int(str(ip_a))-_ipv4_2_int(str(ip_b)))

def mod(ip_a,ip_b):
  '''
  A function to modulus one IPv4 address against another as if they were integers.

  CLI Example::
      salt '*' ipv4_manip.mod 10.10.20.20 0.0.1.0
  '''
  return _int_2_ipv4(_ipv4_2_int(str(ip_a))%_ipv4_2_int(str(ip_b)))

def shift(ip_a,ip_b):
  '''
  A function to shift one IPv4 address in terms of another as if they were integers.

  CLI Example::
      salt '*' ipv4_manip.shift 10.10.20.20 0.0.1.0
  '''
  return sub(str(ip_a),mod(str(ip_a),str(ip_b)))

def reverse_zone(ipv4_str,zone_class="C"):
  '''
  A function to reverse the octets of an IPv4 address, e.g. to determine an in-addr.arpa zone name.

  CLI Example::

      salt '*' ipv4_manip.reverse_zone 255.128.63.16
      salt '*' ipv4_manip.reverse_zone 255.128.63.16 zone_class=B
    
  '''
  if zone_class.upper() == "C":
    zone_shift="0.0.1.0"
  elif zone_class.upper() == "B":
    zone_shift="0.1.0.0"
  elif zone_class.upper() == "A":
    zone_shift="1.0.0.0"
  return shift(ipv4_str,zone_shift)

if False:
  for test_case in ['reverse("255.128.63.16")',
                    'reverse_zone("255.128.63.16")',
                    'reverse_zone("255.128.63.16","b")',
                    'reverse_zone("255.128.63.16",zone_class="a")',
                    'reverse_zone("255.128.63.16","C")',
                    'add("10.10.10.0","0.0.10.20")',
                    'sub("10.10.20.20","0.0.10.20")',
                    'mod("10.10.20.20","0.0.1.0")',
                    'shift("10.10.20.20","0.0.1.0")',
                    'mod("10.10.20.20","0.0.16.0")',
                    'shift("10.10.20.20","0.0.16.0")',
                    'mod("10.10.20.20","0.16.0.0")',
                    'shift("10.10.20.20","0.16.0.0")',
                    'add("10.10.10.0","10.20")',
                    'add("10.10.10.0",10.20)']:
    print "{0:>45s}: {1:>35s}".format(test_case, eval(test_case))

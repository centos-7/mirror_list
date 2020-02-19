#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function
from threading import Thread
import base64
import datetime
import glob
import hashlib
try:
  import httplib
except:
  import http.client as httplib
import json
import mmap
import os
import Queue
import socket
import subprocess
import sys
import time
import urllib3
import requests

class FakeFile:
  def __init__(self,len):
    self.content=self.__content__()
    self.len=len
    self.lo=b''
    self.p=0

  def __content__(self):
    file = open("/dev/zero", "rb")
    try:
      bytes_read = file.read(1024*8)
      while bytes_read:
          yield bytes_read
          bytes_read = file.read(1024*8)
    finally:
        file.close()
  def __len__(self):
    return self.len
  def read(self,chunklen):
    if self.p>self.__len__()/chunklen:
      return None
    d=self.lo
    self.p+=1
    count=len(d)
    try:
      while count<chunklen:
        chunk=next(iter(self.content))
        d+=chunk
        count+=len(chunk)
    except StopIteration as e:
      pass
    if count>chunklen:
      self.lo=d[chunklen:]
    return d[:chunklen]

class ApiReplyFaulty(Exception):
  pass
class ApiUnreachable(Exception):
  pass
class ApiTimeout(Exception):
  pass

class WorkerThread(Thread):
  def run(self):
    try:
      self.died_by=None
      Thread.run(self)
    except Exception as self.died_by:
      pass
    else:
      self.died_by=None

class Client:

  def __resolve__(self,socket_family,name):
    try:
      for tuple in socket.getaddrinfo(name,None,socket_family):
        ip=tuple[-1][0]
        if ip:
          return ip
    except socket.gaierror as e:
      print('\033[1;31mFailed. Resolving '+name+' failed\033[0m')
      raise SystemExit

  def __do_connectivity_test__(self,socket_family,ip):
    try:
      sock=socket.socket(socket_family,socket.SOCK_STREAM)
      sock.settimeout(7)
      sock.connect((ip,180))
      return True
    except (socket.error,socket.timeout) as e:
      return False

  def __dev_list__(self):
    dev_list=[]
    for a,dir_list,b in os.walk('/sys/class/net'):
      for dir in dir_list:
        if not dir=='lo':
          dev_list+=[dir]
    return dev_list

  def __init__(self,host):
    self.host=host
    self.host_ipv6=self.__resolve__(socket.AF_INET6,self.host)
    self.host_ipv4=self.__resolve__(socket.AF_INET,self.host)
    self.ipv6_connectivity=self.__do_connectivity_test__(socket.AF_INET6,self.host_ipv6)
    if self.ipv6_connectivity:
      self.host=self.host_ipv6
    self.ipv4_connectivity=self.__do_connectivity_test__(socket.AF_INET,self.host_ipv4)
    if self.ipv4_connectivity:
      self.host=self.host_ipv4
    if not self.host:
      print('\033[1;31mFailed. No connectivity\033[0m')
      raise SystemExit
    self.client_token=''
    self.keyvalue_list=[]
    self.keyvalue_list+=[{'ipv6_connectivity':self.ipv6_connectivity}]
    self.keyvalue_list+=[{'ipv4_connectivity':self.ipv4_connectivity}]
    self.dev_list=self.__dev_list__()
    for dev in self.dev_list:
      self.keyvalue_list+=[{'dev':dev}]

  def __post__(self,path,body=None,host=None):
    if not host:
      host=self.host
    for trial in range(0,3):
      try:
        httpc=httplib.HTTPConnection(host,180,timeout=30)
        httpc.request('POST',path,json.dumps(body),{'Content-type':'application/json'})
        response=httpc.getresponse()
        body,state=[json.loads(response.read().decode()),response.status]
        if not 'body' in body:
          raise ApiReplyFaulty(body,state)
        if state==404:
          raise ApiReplyFaulty(body,state)
        elif state==500:
          print('\033[1;33mSending data failed\033[0m')
          for i in range(0,20):
            print('  \rRetrying in '+str(20-i)+' second(s) ',end='')
            sys.stdout.flush()
            time.sleep(1)
          print('\r')
          continue
        else:
          return body,state
      except ValueError as e:
        raise ApiReplyFaulty(None,None)
      except (socket.error,socket.timeout) as e:
        raise ApiUnreachable(e)
    raise ApiTimeout

  def log_on(self):
    for trial in range(0,10):
      body,state=self.__post__('/log_on')
      if state==200:
        if not 'client_token' in body:
          raise ApiReplyFaulty(body,state)
        self.client_token=body['client_token']
        return
      elif state==423:
        print('\033[1;33m'+body['body']+'\033[0m')
        raise SystemExit
      elif state==429:
        print('\033[1;33m'+body['body']+'\033[0m')
        raise SystemExit
      elif state==503:
        print('\033[1;33m'+body['body']+'\033[0m')
        for i in range(0,60):
          print('\r  Retrying in '+str(60-i)+' second(s) ',end='')
          sys.stdout.flush()
          time.sleep(1)
        print('\r')
        print('Requesting a test slot .............. : ',end='')
        sys.stdout.flush()
        continue
      else:
        raise ApiReplyFaulty(None,None)
    raise ApiTimeout

  def ping(self,host):
    for trial in range(0,3):
      body,state=self.__post__('/ping',{'token':self.client_token},host)
      if state==200:
        if not body['body']=='pong':
          raise ApiReplyFaulty(body,state)
        if not 'client_token' in body:
          raise ApiReplyFaulty(body,state)
        self.client_token=body['client_token']
        return
      else:
        print('\033[1;33mSending data failed ( '+body['body']+' )\033[0m')
        for i in range(0,20):
          print('    \rRetrying in '+str(20-i)+' second(s) ',end='')
          sys.stdout.flush()
          time.sleep(1)
        print('\r')
        continue
      raise ApiTimeout

  def post_keyvalue_list(self):
    for trial in range(0,3):
      body,state=self.__post__('/keyvalue_list',{'token':self.client_token,'keyvalue_list':self.keyvalue_list})
      if state==200:
        if not 'client_token' in body:
          raise ApiReplyFaulty(body,state)
        self.client_token=body['client_token']
        self.keyvalue_list=[]
        return
      else:
        print('\033[1;33mSending test data failed ( '+body['body']+' )\033[0m')
        for i in range(0,20):
          print('\r  Retrying in '+str(20-i)+' second(s) ',end='')
          sys.stdout.flush()
          time.sleep(1)
        print('\r')
        continue
    raise ApiTimeout

  def log_off(self):
    if self.client_token:
      for trial in range(0,3):
        body,state=self.__post__('/log_off',{'token':self.client_token})
        if state==200:
          if not 'location' in body:
            raise ApiReplyFaulty(body,state)
          return body['location']
        else:
          print('\033[1;33mSending data failed ( '+body['body']+' )\033[0m')
          for i in range(0,20):
            print('\r  Retrying in '+str(20-i)+' second(s) ',end='')
            sys.stdout.flush()
            time.sleep(1)
          print('\r')
          continue
      raise ApiTimeout

  def build_proc_dict(self):
    with open('/proc/meminfo','r') as file:
      self.keyvalue_list+=[{'proc_meminfo':file.read()}]

  def __build_dict_by_exec__(self,key):
    pipe=subprocess.Popen(' '.join(key),stdout=subprocess.PIPE,stderr=subprocess.PIPE,shell=True)
    key='_'.join(key).replace(' ','_')
    stdo,stde=pipe.communicate()
    self.keyvalue_list+=[{key+'_stdo':stdo}]
    self.keyvalue_list+=[{key+'_stde':stde}]
    self.keyvalue_list+=[{key+'_return_value':pipe.wait()}]

  def build_ip_dict(self):
    for dev in self.dev_list:
      for opt in ['a','l','r','-6 r']:
        self.__build_dict_by_exec__(['ip',opt,'show dev',dev])

  def build_ethtool_dict(self):
    for dev in self.dev_list:
      for opt in ['-i','-S']:
        self.__build_dict_by_exec__(['ethtool',opt,dev])

  def build_miitool_dict(self):
    for dev in self.dev_list:
      for opt in ['-v']:
        self.__build_dict_by_exec__(['mii-tool',opt,dev])

  def do_ping_test(self,binary,ip):
    print('  Performing the ping test ........... : ',end='')
    sys.stdout.flush()
    self.__build_dict_by_exec__([binary,'-c 20 -i .2 -w 7',ip])
    print('\033[1;32mDone\033[0m')

  def __build_net_dict__(self,key_pf=''):
    for dev in self.dev_list:
      for file in glob.glob(os.path.join('/','sys','class','net',dev,'stat*','*x_bytes')):
        try:
          f=open(file,'r')
          self.keyvalue_list+=[{key_pf+'_dev_'+dev+'_'+file.split('/').pop():f.read()}]
          f.close()
        except Exception as e:
          continue

  def __upload_test_worker__(self,ip):
    f=FakeFile(209715200)
    httpc=httplib.HTTPConnection(ip,181,timeout=30)
    httpc.request('POST','/put/'+self.client_token,f)


  def do_upload_test(self,name,ip):
    key='upload_test_'+name
    for trial in range(0,3):
      t_list=[]
      for i in range(0,4):
        t=WorkerThread(target=self.__upload_test_worker__,args=(ip,))
        t_list+=[t]
      print('  Performing the upload test ......... : ',end='')
      sys.stdout.flush()
      self.__build_net_dict__(key)
      for t in t_list:
        t.daemon=True
        t.start()
      of=datetime.datetime.now()
      for t in t_list:
        t.join(300)
      self.keyvalue_list+=[{key+'_timedelta':(datetime.datetime.now()-of).total_seconds()}]
      self.__build_net_dict__(key)
      ok=True
      for t in t_list:
        if t.died_by:
          ok=False
          break
      if ok:
        print('\033[1;32mDone\033[0m')
        break
      else:
        if trial<2:
          print('\033[1;33mFailed\033[0m')
          for i in range(0,20):
            print('\r    Retrying in '+str(20-i)+' second(s) ',end='')
            sys.stdout.flush()
            time.sleep(1)
          print('\r')
          continue
        else:
          print('\033[1;33mFailed. Continuing anyway\033[0m')
          print('    \033[1;33mFailure details :\033[0m')
          for i,t in enumerate(t_list):
            if t.died_by:
              try:
                raise t.died_by
              except (IOError,socket.error,socket.timeout) as e:
                print('      \033[1;33mUpload worker '+str(i+1)+' died ( '+str(e)+' )\033[0m')

  def __download_test_worker__(self,ip,key,http,queue,num):
    if key == 'download_test_ipv6': ip='['+ip+']'
    if num+1 == 1: queue.put(datetime.datetime.now())
    url='http://'+ip+':181/200M.testfile'
    hash=hashlib.md5()
    f=requests.get(url, stream=True)
    for chunk in f.iter_content(1024 * 8):
      if chunk:
        hash.update(chunk)
        i=0
    self.keyvalue_list+=[{key+'_hash':hash.hexdigest()}]

  def do_download_test(self,name,ip):
    key='download_test_'+name
    http = urllib3.PoolManager()
    queue=Queue.Queue()
    for trial in range(0,5):
      t_list=[]
      for i in range(0,4):
        t=WorkerThread(target=self.__download_test_worker__,args=(ip,key,http,queue,i))
        t_list+=[t]
      print('  Performing the download test ....... : ',end='')
      sys.stdout.flush()
      self.__build_net_dict__(key)
      for t in t_list:
        t.daemon=True
        t.start()
      for t in t_list:
        t.join(300)
      of=queue.get()
      self.keyvalue_list+=[{key+'_timedelta':(datetime.datetime.now()-of).total_seconds()}]
      self.__build_net_dict__(key)
      ok=True
      for t in t_list:
        if t.died_by:
          ok=False
          break
      if ok:
        print('\033[1;32mDone\033[0m')
        break
      else:
        if trial<2:
          print('\033[1;33mFailed\033[0m')
          for i in range(0,20):
            print('\r    Retrying in '+str(20-i)+' second(s) ',end='')
            sys.stdout.flush()
            time.sleep(1)
          print('\r')
          continue
        else:
          print('\033[1;33mFailed. Continuing anyway\033[0m')
          print('    \033[1;33mFailure details :\033[0m')
          for i,t in enumerate(t_list):
            if t.died_by:
              try:
                raise t.died_by
              except (IOError,socket.error,socket.timeout) as e:
                print('      \033[1;33mDownload worker '+str(i+1)+' died ( '+str(e)+' )\033[0m')

  def __tcp_test_worker__(self,socket_type,ip,port):
    sock_list=[]
    for i in range(0,100):
      sock=socket.socket(socket_type,socket.SOCK_STREAM)
      sock.settimeout(8)
      sock.connect((ip,port))
      sock.send(self.client_token)
      sock_list+=[sock]
      time.sleep(.008)
    while sock_list:
      for sock in sock_list:
        try:
          a=sock.recv(13)
        except socket.timeout:
          sock.close()
          sock_list.remove(sock)
          continue
        if not a:
          sock.shutdown(2)
          sock.close()
          sock_list.remove(sock)
          continue
        sock.sendall(a)
      time.sleep(.08)

  def do_tcp_test(self,socket_family,ip,port):
    for trial in range(0,2):
      t_list=[]
      for i in range(0,10):
        t=WorkerThread(target=self.__tcp_test_worker__,args=(socket_family,ip,port,))
        t_list+=[t]
      print('  Performing the tcp test ............ : ',end='')
      sys.stdout.flush()
      for t in t_list:
        t.daemon=True
        t.start()
        time.sleep(.8)
      for t in t_list:
        t.join(300)
      ok=True
      for t in t_list:
        if t.died_by:
          ok=False
          break
      if ok:
        print('\033[1;32mDone\033[0m')
        break
      else:
        if trial<2:
          print('\033[1;33mFailed\033[0m')
          for i in range(0,20):
            print('\r    Retrying in '+str(20-i)+' second(s) ',end='')
            sys.stdout.flush()
            time.sleep(1)
          print('\r')
          continue
        else:
          print('\033[1;33mFailed. Continuing anyway\033[0m')
          print('    \033[1;33mFailure details :')
          for i,t in enumerate(t_list):
            if t.died_by:
              try:
                raise t.died_by
              except (socket.error,socket.timeout) as e:
                print('      \033[1;33mWorker '+str(i+1)+' died ( '+str(e)+' )\033[0m')

try:
  print('Requesting an test slot .............. : ',end='')
  sys.stdout.flush()
  client=Client('speedtest.your-server.de')
  client.log_on()
  print('\033[1;32mDone\033[0m')
  print('')
  t_list=[]
  t_list+=[Thread(target=client.build_proc_dict)]
  t_list+=[Thread(target=client.build_ip_dict)]
  t_list+=[Thread(target=client.build_ethtool_dict)]
  t_list+=[Thread(target=client.build_miitool_dict)]
  print('Collecting system data ............... : ',end='')
  sys.stdout.flush()
  for t in t_list:
    t.daemon=True
    t.start()
  for t in t_list:
    t.join(300)
  client.post_keyvalue_list()
  print('\033[1;32mDone\033[0m')
  print('')
  print('Performing IPv6 tests: ',end='')
  sys.stdout.flush()
  if client.ipv6_connectivity:
    client.ping(client.host_ipv6)
    print('')
    print('')
    client.do_ping_test('ping6',client.host_ipv6)
    client.do_upload_test('ipv6',client.host_ipv6)
    client.do_download_test('ipv6',client.host_ipv6)
    client.do_tcp_test(socket.AF_INET6,client.host_ipv6,182)
  else:
    print('  \033[1;33mNo connectivity. Continuing anyway\033[0m')
  print('')
  print('Performing IPv4 tests: ',end='')
  sys.stdout.flush()
  if client.ipv4_connectivity:
    client.ping(client.host_ipv4)
    print('')
    print('')
    client.do_ping_test('ping',client.host_ipv4)
    client.do_upload_test('ipv4',client.host_ipv4)
    client.do_download_test('ipv4',client.host_ipv4)
    client.do_tcp_test(socket.AF_INET,client.host_ipv4,183)
  else:
    print('  \033[1;33mNo connectivity. Continuing anyway\033[0m')
  client.post_keyvalue_list()
  t_list=[]
  t_list+=[Thread(target=client.build_ethtool_dict)]
  t_list+=[Thread(target=client.build_miitool_dict)]
  print('')
  print('Collecting comparative system data ... : ',end='')
  sys.stdout.flush()
  for t in t_list:
    t.daemon=True
    t.start()
  for t in t_list:
    t.join(300)
  client.post_keyvalue_list()
  print('\033[1;32mDone\033[0m')
  print('')
except ApiReplyFaulty as e:
  print('\033[1;31mReceiving data failed ( Invalid API reply )\033[0m')
except ApiUnreachable as e:
  print('\033[1;31mSending data failed ( '+str(e)+' )\033[0m')
except ApiTimeout as e:
  print('\033[1;31mFailed. Exiting\033[0m')
except KeyboardInterrupt as e:
  print('')
except Exception as e:
  print(sys.exc_info())
  print(e)
finally:
  try:
    print('')
    print('Releasing the test slot .............. : ',end='')
    sys.stdout.flush()
    location=client.log_off()
    print('\033[1;32mDone\033[0m')
    print('')
    print('See the test results at '+location)
  except Exception as e:
    print('\033[1;31mExiting\033[0m')
    raise SystemExit
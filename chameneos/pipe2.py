#!/usr/bin/env python3
##
#  Derived from chameneos example by Leon Timmermans.
#    https://github.com/Leont/threads-lite/blob/master/examples/chameneos
#
#  Other Python solutions.
#    https://pybenchmarks.org/u64q/performance.php?test=chameneosredux
#
#  chameneos-redux using os pipes for synchronization
#    contributed by Mario Roy 2025-04-09
##

import os, struct, sys, time
import multiprocessing as mp

class Channel:

    def __init__(self):
        self.rd, wr = os.pipe()
        self.wr = os.fdopen(wr, 'wb', 0); # fdopen, so can self.wr.flush()

    def __del__(self):
        self.close()

    def __writeall(self, data):
        while data:
            num_written = self.wr.write(data)
            data = data[num_written:]
        self.wr.flush()

    def send(self, s):
        if s is None:
            plen = struct.pack('!i', -1)
            self.__writeall(plen)
            return
        if not isinstance(s, str): s = str(s)
        if len(s) > 0:
            bstr = bytes(s, 'utf-8')
            plen = struct.pack('!i', len(bstr))
            self.__writeall(plen + bstr)
        else:
            plen = struct.pack('!i', 0)
            self.__writeall(plen)

    def recv(self):
        slen = struct.unpack('!i', os.read(self.rd, 4))[0]
        if slen > 0: return os.read(self.rd, slen).decode('utf-8')
        if slen < 0: return None
        return ""

    def close(self):
        try:
            self.wr.close() # os.fdopen file handle
            os.close(self.rd) # os.pipe file descriptor
        except Exception:
            pass


if len(sys.argv) <= 1:
    print('No argument given', file=sys.stderr)
    exit(1)

# synchronization: creatures communicate on channel 0 to broker
_chnls = [Channel() for _ in range(1 + 10)]

# colors and matching
_creature_colors = ['blue', 'red', 'yellow']

def complement(c1, c2):

    if c1 == c2: return c1

    if c1 == 'red':
        if c2 == 'blue': return 'yellow'
        return 'blue'

    if c1 == 'blue':
        if c2 == 'red': return 'yellow'
        return 'red'

    if c2 == 'blue': return 'red'
    return 'blue'

_complement = dict(((c1, c2), complement(c1, c2))
                  for c1 in _creature_colors
                  for c2 in _creature_colors)


# reporting
def show_complement():

    for c1 in _creature_colors:
        for c2 in _creature_colors:
            print('%s + %s -> %s' % (c1, c2, _complement[(c1, c2)]))

    print('')

def spellout(n):

    numbers = ['zero', 'one', 'two', 'three', 'four',
               'five', 'six', 'seven', 'eight', 'nine']

    return ' ' + ' '.join(numbers[int(c)] for c in str(n))


# the zoo
def creature(my_id, color):

    meetings, metself = 0, 0

    run = 1
    while run:
        _chnls[0].send(f"{my_id} {color}")
        venue = _chnls[my_id].recv().split()
        if venue[0] == 'stop':
            # leave game
            print(f"{meetings} {spellout(metself)}")
            _chnls[0].send(meetings)
            run = 0
        else:
            # save my results
            oid, ocolor = venue
            if oid == my_id: metself += 1
            meetings += 1
            color = _complement[(color, ocolor)]


def __creature(my_id, color):
    try:
        creature(my_id, color)
    except KeyboardInterrupt:
        pass


def broker(n, nthrs):

    total_meetings = 0

    while n:
        # await two creatures
        c1 = _chnls[0].recv().split(); id1 = int(c1[0])
        c2 = _chnls[0].recv().split(); id2 = int(c2[0])
        # registration, exchange colors
        _chnls[id1].send(f"{c2[0]} {c2[1]}")
        _chnls[id2].send(f"{c1[0]} {c1[1]}")
        n -= 1

    while nthrs:
        res = _chnls[0].recv().split()
        if len(res) == 2:
            # notify stop game
            my_id = int(res[0])
            _chnls[my_id].send('stop')
        else:
            # tally meetings
            meetings = int(res[0])
            total_meetings += meetings
            nthrs -= 1

    return total_meetings


# game
def pall_mall(n, colors):

    print(' ' + ' '.join(colors))

    thrs = list()
    for i in range(len(colors)):
        thrs.append(mp.Process(target=__creature, args=(i+1, colors[i])))
        thrs[-1].start()

    total_meetings = broker(n, len(thrs))

    for t in thrs:
        t.join()

    print(spellout(total_meetings))
    print('')


def chameneosiate(n):

    time_start = time.time()

    show_complement()
    pall_mall(n, ['blue', 'red', 'yellow'])
    pall_mall(n, ['blue', 'red', 'yellow', 'red', 'yellow',
                  'blue', 'red', 'yellow', 'red', 'blue'])

    time_end = time.time()
    print("duration: {:.3f} seconds".format(time_end - time_start))


try:
    chameneosiate(int(sys.argv[1]))
except KeyboardInterrupt:
    print('')
    sys.exit(1)


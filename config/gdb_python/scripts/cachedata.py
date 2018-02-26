import gdb
from mystd.v6 import stl_util

MARKET_QQZS = 100

def get_cache_set():
    dset_type = gdb.lookup_type('CMultiCacheDataSet').pointer()
    return gdb.parse_and_eval('CMultiCacheDataSet::GetInstance()').cast(dset_type)

def get_pcproc():
    conmag = gdb.parse_and_eval('CMyConMagSvc::s_pServiceHandler').dereference()
    pptype = gdb.lookup_type('CPcProcess').pointer()
    uchar_ptr = gdb.lookup_type('unsigned char').pointer()
    pcprocess = conmag['m_pProc'].cast(uchar_ptr) - 8
    return pcprocess.cast(pptype)

class MarketIterator(object):
    def __init__(self):
        self.market_map = get_cache_set()['m_mapMarket']

    def __len__(self):
        return stl_util.get_map_size(self.market_map)

    def __iter__(self):
        keytype = stl_util.get_map_keytype(self.market_map)
        imp_type = gdb.lookup_type('CMultiCacheDataImp')
        uchar_ptr = gdb.lookup_type('unsigned char').pointer()
        sum_type = gdb.lookup_type('CMultiCacheDataSum')
        for pair in stl_util.StdMapIterator(self.market_map):
            market = pair['first'].cast(keytype)
            if market != MARKET_QQZS:
                value = pair['second'].cast(uchar_ptr) - 8
                value = value.cast(imp_type.pointer())
                yield int(market), value.dereference()
            else:
                value = pair['second'].cast(sum_type.pointer())
                yield int(market), value.dereference()
                spl_markets = value['m_mapMarket']
                for spl_pair in stl_util.StdMapIterator(spl_markets):
                    m = spl_pair['second']
                    yield int(spl_pair['first'].cast(keytype)), m.dereference()

class PrintHang(gdb.Command):
    '''
    Print all the configured markets and hangup markets.
    Usage: phang
    '''
    def __init__(self):
        super(self.__class__, self).__init__("phang", gdb.COMMAND_NONE)
        self.dont_repeat()

    def invoke(self, args, from_tty):
        cacheset = get_cache_set()
        print('all markets: { %s }' % ', '.join(str(x) for x in stl_util.get_iterator(cacheset['m_vecAllMarketIDs'])))
        pcproc = get_pcproc()
        print('hangup markets: { %s }' % ', '.join(str(x) for x in stl_util.get_iterator(pcproc['m_setHangupMarket'])))

class PrintMarket(gdb.Command):
    '''
    Print the info machine of a market
    Usage: pmarket <market>
    '''
    def __init__(self):
        super(self.__class__, self).__init__("pmarket", gdb.COMMAND_NONE)
        self.dont_repeat()

    def invoke(self, args, from_tty):
        markets = args.split()
        if len(markets) < 1:
            raise ValueError('incorrect arguments')

        dest_market = int(markets[0])
        for market, imp in MarketIterator():
            if market == dest_market:
                print(imp['m_mapStock'])
                break


PrintMarket()
PrintHang()

import gdb
from mystd.v6 import stl_util

class Counter(object):
    def __init__(self, *args, **kwargs):
        super(Counter, self).__init__(*args, **kwargs)
        self.used = 0
        self.allocated = 0

    def add_vec_bytes(self, vec):
        size, capacity = stl_util.vec_size(vec)
        elem_type = vec.type.template_argument(0)
        self.used += size * elem_type.sizeof
        self.allocated += capacity * elem_type.sizeof

    def add(self, *args):
        if len(args) == 1 and isinstance(args[0], Counter):
            self.used += args[0].used
            self.allocated += args[0].allocated
        else:
            self.used += args[0]
            if len(args) == 1:
                self.allocated += args[0]
            else:
                self.allocated += args[1]

    def add_page_set(self, page_set):
        block_map = page_set['m_mapBlocks']
        self.add_pod_map(block_map)
        for pair in stl_util.stl_util.RbtreeIterator(block_map):
            block = pair['second'].dereference()
            self.add(int(block['m_intPageCount'] * block['m_intPageSize']))

    def add_pod_map(self, m):
        map_bytes = stl_util.get_map_size(m) * stl_util.get_map_nodetype(m).sizeof
        self.used += map_bytes
        self.allocated += map_bytes

    def add_pod_mapvec(self, m):
        map_bytes = stl_util.get_map_size(m) * stl_util.get_map_nodetype(m).sizeof
        self.add(map_bytes)
        for pair in stl_util.stl_util.RbtreeIterator(m):
            self.add_vec_bytes(pair['second'])

    def add_string_bytes(self, string):
        size, capacity = stl_util.string_bytes(string)
        self.add(size, capacity)

    def __str__(self):
        return 'used=%s, allocated=%s' % (stl_util.size_format(self.used),
                                          stl_util.size_format(self.allocated))

class Summary(gdb.Command):
    '''
    Print some summary info of a map:
    Usage: summary <map>
    '''
    def __init__(self):
        super(self.__class__, self).__init__("summary", gdb.COMMAND_NONE)
        self.dont_repeat()

    def get_conmag_bytes(self):
        nr_bytes = 0
        conmag = gdb.parse_and_eval('CMyConMagSvc::s_pServiceHandler').dereference()
        nr_bytes += conmag.type.sizeof
        base_objs = conmag['m_vectObjs']
        vecobj_size = stl_util.vec_size(base_objs)
        print('conmag vectobjs size=%s, capacity=%s' % (vecobj_size[0],
                                                        vecobj_size[1]))
        cg_used = stl_util.vec_bytes(base_objs)
        nr_bytes += cg_used[1]
        block_bytes = 8 * 4096 * 8192
        nr_bytes += vecobj_size[0] * (block_bytes +
                                                gdb.lookup_type('NetIO::CConMag').sizeof)
        print('connmag used=%s' % stl_util.size_format(nr_bytes))
        return nr_bytes

    def invoke(self, args, from_tty):
        c = Counter()
        conmag = gdb.parse_and_eval('CMyConMagSvc::s_pServiceHandler').dereference()
        pptype = gdb.lookup_type('CPcProcess').pointer()
        uchar_ptr = gdb.lookup_type('unsigned char').pointer()
        c.add(pptype.sizeof)
        pcprocess = conmag['m_pProc'].cast(uchar_ptr) - 8
        pcprocess = pcprocess.cast(pptype)
        for pair in stl_util.RbtreeIterator(pcprocess['m_hangupreq']):
            for item in StdVectorIterator.fromvec(pair['second']):
                c.add_vec_bytes(item)

        c.add(PrintCache.calc_all_data())
        c.add(self.stl_util.conmag_bytes())
        c.add(PrintMultiTrans.calc_all_markets())

        print('mds summary, %s' % c)

class StdVectorIterator:
    def __init__ (self, start, finish, is_bitvec):
        self.is_bitvec = is_bitvec
        if is_bitvec:
            self.item   = start['_M_p']
            self.so     = start['_M_offset']
            self.finish = finish['_M_p']
            self.fo     = finish['_M_offset']
            itype = self.item.dereference().type
            self.isize = 8 * itype.sizeof
        else:
            self.item = start
            self.finish = finish
        self.count = 0

    def __iter__(self):
        return self

    def next(self):
        self.count = self.count + 1
        if self.is_bitvec:
            if self.item == self.finish and self.so >= self.fo:
                raise StopIteration
            elt = self.item.dereference()
            if elt & (1 << self.so):
                obit = 1
            else:
                obit = 0
            self.so = self.so + 1
            if self.so >= self.isize:
                self.item = self.item + 1
                self.so = 0
            return obit
        else:
            if self.item == self.finish:
                raise StopIteration
            elt = self.item.dereference()
            self.item = self.item + 1
            return elt

    @staticmethod
    def fromvec(vec):
        return StdVectorIterator(vec['_M_impl']['_M_start'],
                                 vec['_M_impl']['_M_finish'],
                                 False)

    __next__ = next

class PrintCache(gdb.Command):
    '''
    Print some summary info of a map:
    Usage: pcache
    '''
    def __init__(self):
        super(self.__class__, self).__init__("pcache", gdb.COMMAND_NONE)
        self.dont_repeat()

    def invoke(self, args, from_tty):
        PrintCache.calc_all_data()

    @staticmethod
    def _calc_stock_memory(value):
        du = value['px'].dereference()
        counter = Counter()
        counter.add(du.type.sizeof)
        counter.add(1024) # tmpbuf
        counter.add_string_bytes(du['m_strUniqueID'])
        counter.add_vec_bytes(du['m_nrtmin'])
        counter.add_vec_bytes(du['m_mx'])
        counter.add_vec_bytes(du['m_mxs'])
        counter.add_vec_bytes(du['m_kmin1'])
        counter.add_vec_bytes(du['m_kmin5'])
        counter.add_vec_bytes(du['m_kmin15'])
        counter.add_vec_bytes(du['m_kmin30'])
        counter.add_vec_bytes(du['m_kmin60'])
        counter.add_vec_bytes(du['m_kmin120'])
        counter.add_vec_bytes(du['m_dayk'])
        #counter.add_pod_mapvec(du['m_mapBuyBrokerNo'])
        #counter.add_pod_mapvec(du['m_mapSellBrokerNo'])
        for item in StdVectorIterator.fromvec(du['m_belongblocks']):
            counter.add_string_bytes(item)
        uniq_id = str(du['m_strUniqueID'])
        for pair in stl_util.RbtreeIterator(du['m_mapRegInfo']):
            PrintCache.examine_reginfo(pair['second'], '%s %s' % (uniq_id,
                                                                  str(pair['first'])))
            counter.add(stl_util.podset_bytes(pair['second']['m_setRegInfo']))
        return counter

    @staticmethod
    def get_grouptask_size(task):
        groups = task['m_mapGroups']
        counter = Counter()
        counter.add(gdb.lookup_type('TaskQueue').sizeof)
        counter.add_pod_map(groups)
        for pair in stl_util.RbtreeIterator(groups):
            counter.add_string_bytes(pair['first'])
            counter.add_vec_bytes(pair['second']['m_listSubTasks'])

        return (stl_util.get_map_size(groups), counter)

    @staticmethod
    def calc_all_data():
        print('\033[31mcaculating cache data\033[0m')
        dset_type = gdb.lookup_type('CMultiCacheDataSet').pointer()
        mset = gdb.parse_and_eval('CMultiCacheDataSet::GetInstance()').cast(dset_type)

        data_set = mset['m_mapMarket']
        keytype = stl_util.get_map_keytype(data_set)
        sum_type = gdb.lookup_type('CMultiCacheDataSum')
        imp_type = gdb.lookup_type('CMultiCacheDataImp')
        uchar_ptr = gdb.lookup_type('unsigned char').pointer()
        all_counter = Counter()
        all_counter.add_pod_map(data_set)
        for pair in stl_util.StdMap(data_set):
            market = pair['first'].cast(keytype)
            if market == 100:
                value = pair['second'].cast(sum_type.pointer())
                spl_markets = value['m_mapMarket']
                spl_mstock = value['m_mapStockMarket']
                qqzs_counter = Counter()
                qqzs_counter.add(sum_type.sizeof)
                qqzs_counter.add_pod_map(spl_markets)
                qqzs_counter.add_pod_map(spl_mstock)
                for spl_pair in stl_util.StdMap(spl_markets):
                    c = PrintCache.calc_spl_market(spl_pair['second'])
                    qqzs_counter.add(c)
                print('QQZS, %s' % qqzs_counter)
                all_counter.add(qqzs_counter)
            else:
                value = pair['second'].cast(uchar_ptr) - 8
                value = value.cast(imp_type.pointer())
                c = PrintCache.calc_dataimp_market(value)
                all_counter.add(c)

        print('all markets, %s' % all_counter)

        qtlist = gdb.parse_and_eval('CStdQtListImp::GetInstance()')
        qtlist_counter = Counter()
        qtlist_counter.add_vec_bytes(qtlist['m_qt'])
        qtlist_counter.add_vec_bytes(qtlist['m_qtold'])
        qtlist_counter.add_vec_bytes(qtlist['m_fin'])
        qtlist_counter.add_vec_bytes(qtlist['m_finold'])
        print('qtlist %s' % qtlist_counter)
        all_counter.add(qtlist_counter)

        broker_info = mset['m_brokerInfo']
        bi_counter = Counter()
        bi_counter.add_vec_bytes(broker_info['m_vectData'])
        bi_counter.add_vec_bytes(broker_info['m_bufdata'])
        print('brokerinfo, %s' % bi_counter)
        all_counter.add(bi_counter)

        mobile_dict = mset['m_mobiledict']
        md_bytes = mobile_dict.type.sizeof + stl_util.podset_bytes(mobile_dict['m_data'])
        print('mobie_dict, used=%s' % stl_util.size_format(md_bytes))
        all_counter.add(md_bytes)

        raw_ds = mset['m_rawdataset']
        rd_counter = Counter()
        rd_counter.add_pod_map(raw_ds['m_data'])
        for pair in stl_util.RbtreeIterator(raw_ds['m_data']):
            rd_counter.add_vec_bytes(pair['second']['m_bufdata'])
        print('rawdataset, %s' % rd_counter)
        all_counter.add(rd_counter)

        block_map = mset['m_blockmap']
        bm_counter = Counter()
        bm_counter.add_vec_bytes(block_map['m_bufdata'])
        bm_data = block_map['m_data']
        bm_nodetype = stl_util.get_map_nodetype(bm_data)
        bm_counter.add(bm_nodetype.sizeof * stl_util.get_map_size(bm_data))
        for pair in stl_util.RbtreeIterator(bm_data):
            bm_counter.add_vec_bytes(pair['second']['m_data'])
        print('blockmap, %s' % bm_counter)

        all_counter.add(bm_counter)

        print('cache used, %s' % all_counter)
        return all_counter

    @staticmethod
    def calc_market_stocks(market_data):
        value = market_data['m_mapStock']
        nodetype = stl_util.get_map_nodetype(value)
        nodetype = nodetype.pointer()
        counter = Counter()
        spdu_type = gdb.lookup_type('boost::shared_ptr<CStdDataUnitImp>')
        for pair in stl_util.RbtreeIterator(value):
            counter.add_string_bytes(pair['first'])
            c = PrintCache._calc_stock_memory(pair['second'].cast(spdu_type))
            counter.add(c)
        return counter

    @staticmethod
    def calc_spl_market(market_data):
        c = PrintCache.calc_market_stocks(market_data)
        c.add(market_data.type.sizeof)
        return c

    @staticmethod
    def examine_reginfo(value, reg_type):
        size = stl_util.set_size(value['m_setRegInfo'])
        if size:
            print('%s, reg size=%s' % (reg_type, size))

    @staticmethod
    def calc_dataimp_market(market_data):
        market = int(market_data['m_wMarketID'])
        print('caculating market %s' % market)
        c = Counter()
        c.add(market_data.type.sizeof)
        broker_trace = market_data['m_mapBroker']
        bt_count = Counter()
        bt_count.add_pod_map(broker_trace)
        for pair in stl_util.RbtreeIterator(broker_trace):
            bt_ref = pair['second']['px']
            bt_count.add(bt_ref.type.sizeof)
            trace = bt_ref['m_trace']
            bt_count.add_pod_map(trace['mapBuyBT'])
            for item in stl_util.RbtreeIterator(trace['mapBuyBT']):
                bt_count.add(stl_util.podset_bytes(item['second']))
            bt_count.add_pod_map(trace['mapSellBT'])
            for item in stl_util.RbtreeIterator(trace['mapSellBT']):
                bt_count.add(stl_util.podset_bytes(item['second']))

            for reginfo in stl_util.RbtreeIterator(bt_ref['m_mapRegInfo']):
                PrintCache.examine_reginfo(reginfo['second'],
                                           bt_ref['m_usBrokerID'])
                bt_count.add(stl_util.podset_bytes(reginfo['second']['m_setRegInfo']))

        print('broker trace, %s' % bt_count)

        c.add_pod_map(market_data['m_mapRawFin'])
        c.add_pod_map(market_data['m_mapBelongBlocks'])

        dict_info = market_data['m_dict']
        PrintCache.examine_reginfo(dict_info, "stock_dict")
        c.add_vec_bytes(dict_info['m_vectData'])
        c.add_vec_bytes(dict_info['m_bufdata'])

        for pair in stl_util.RbtreeIterator(market_data['m_mapBelongBlocks']):
            c.add_string_bytes(pair['first'])
            block_stocks = pair['second']
            c.add_vec_bytes(block_stocks)
            for item in StdVectorIterator.fromvec(block_stocks):
                c.add_string_bytes(item)

        mi = market_data['m_marketinfo']
        PrintCache.examine_reginfo(mi, "market_info")
        for pair in stl_util.RbtreeIterator(mi['m_mapData']):
            c.add_vec_bytes(pair['second']['m_vectDataSpl'])

        c.add(PrintCache.calc_market_stocks(market_data))
        print('market=%s, %s' % (str(market), c))

        return c

class PrintMultiTrans(Counter, gdb.Command):
    '''
    Print some summary info of a map:
    Usage: ptrans
    '''
    def __init__(self):
        super(self.__class__, self).__init__("ptrans", gdb.COMMAND_NONE)
        self.dont_repeat()

    def invoke(self, args, from_tty):
        PrintMultiTrans.calc_all_markets()

    @staticmethod
    def calc_raw_data():
        ins = gdb.parse_and_eval('MultiTrans::CTabRawData::s_pInstance')
        raw_data = ins['m_mapData']
        used = stl_util.get_map_size(raw_data) * stl_util.get_map_nodetype(raw_data).sizeof
        for pair in stl_util.RbtreeIterator(raw_data):
            r = pair['second']
            used += r['m_intKeyLen'] + r['m_intDataLen']
        print('rawdata used=%s' % stl_util.size_format(used))
        return used

    @staticmethod
    def calc_connection_set():
        c = Counter()
        conn_set = gdb.parse_and_eval('MultiTrans::CMarketConSet::s_pInstance')
        c.add_vec_bytes(conn_set['mConMaster'])
        c.add_vec_bytes(conn_set['mConSlaver'])
        for item in StdVectorIterator.fromvec(conn_set['mConMaster']):
            c.add_page_set(item['m_pageset'])
            c.add_vec_bytes(item['m_ionode']['m_vectInputBuf']['mBuff'])
        print('trans conn, %s' % c)
        return c

    @staticmethod
    def calc_all_markets():
        print('\033[31mcaculating multitrans\033[0m')
        market_set = gdb.parse_and_eval('MultiTrans::CMarketSet::s_pInstance')
        markets = market_set['m_mapMarket']
        nr_market = stl_util.get_map_size(markets)
        nodetype = stl_util.get_map_nodetype(markets)
        valtype = stl_util.get_map_valtype(markets)

        c = Counter()
        c.add(PrintMultiTrans.calc_connection_set())
        c.used = (nodetype.sizeof + valtype.target().sizeof) * nr_market
        c.allocated = c.used

        block_map = gdb.parse_and_eval('MultiTrans::CTabBlockMap::s_pInstance')
        c.add_pod_map(block_map['m_mapData'])

        rawdata_bytes = PrintMultiTrans.calc_raw_data()
        c.used += rawdata_bytes
        c.allocated += rawdata_bytes

        for pair in stl_util.RbtreeIterator(markets):
            cmarket = Counter()
            market_data = pair['second']
            cmarket.add_vec_bytes(market_data['m_time']['m_current'])
            cmarket.add_pod_map(market_data['m_qt']['m_mapData'])
            cmarket.add_pod_map(market_data['m_blockqt']['m_mapData'])
            cmarket.add_pod_map(market_data['m_dict']['m_mapData'])
            cmarket.add_pod_map(market_data['m_mmp']['m_mapData'])
            cmarket.add_pod_mapvec(market_data['m_rt']['m_data'])
            cmarket.add_pod_mapvec(market_data['m_mx']['m_data'])
            cmarket.add_pod_map(market_data['m_BrokerQueue']['m_mapData'])
            cmarket.add_pod_map(market_data['m_qtex']['m_mapData'])
            cmarket.add_pod_map(market_data['m_cas']['m_mapData'])
            cmarket.add_pod_map(market_data['m_vcm']['m_mapData'])
            cmarket.add_pod_map(market_data['m_indexQt']['m_mapData'])
            cmarket.add_pod_map(market_data['m_finance']['m_mapData'])
            cmarket.add_pod_map(market_data['m_warrantsQt']['m_mapData'])
            c.add(cmarket)
            print('market=%d, %s' % (int(pair['first']), cmarket))
        print('transmodel, used=%s, total=%s' % (stl_util.size_format(c.used),
                                          stl_util.size_format(c.allocated)))
        return c

    @staticmethod
    def calc_market_stocks(market_data):
        value = market_data['m_mapStock']
        keytype = value.type.template_argument(0).const()
        valuetype = value.type.template_argument(1)
        nodetype = gdb.lookup_type('std::_Rb_tree_node< std::pair< %s, %s > >' % (keytype, valuetype))
        nodetype = nodetype.pointer()
        used, total = 0, 0
        spdu_type = gdb.lookup_type('boost::shared_ptr<CStdDataUnitImp>')
        for pair in stl_util.RbtreeIterator(value):
            sused, stotal = PrintCache._calc_stock_memory(pair['second'].cast(spdu_type))
            used += sused
            total += stotal
        return used, total


PrintCache()
PrintMultiTrans()
Summary()

# Pretty-printers for libstc++.

import gdb
import re
import sys

stl_iter_dict = {}
stl_container_dict = {}

def size_format(b):
	if b < 1000:
		return '%i' % b + 'B'
	elif 1000 <= b < 1000000:
		return '%.1f' % float(b/1000.0) + 'KB'
	elif 1000000 <= b < 1000000000:
		return '%.1f' % float(b/1000000.0) + 'MB'
	elif 1000000000 <= b < 1000000000000:
		return '%.1f' % float(b/1000000000.0) + 'GB'
	elif 1000000000000 <= b:
		return '%.1f' % float(b/1000000000000.0) + 'TB'

def parse_and_eval(expression):
    if expression.find('.') == -1:
        return gdb.parse_and_eval(expression)
    else:
        fields = expression.split('.')
        val = gdb.parse_and_eval(fields[0])
        for f in fields[1:]:
            for k, v in stl_container_dict.items():
                if re.search(k, val.type.tag):
                    val = v(val).get_field(f)
                    break
            else:
                break

        return val

def get_iterator(val):
    typename = val.type.tag
    for k, v in stl_iter_dict.items():
        if re.search(k, typename):
            return v(val)
    return None

def get_container(val):
    typename = val.type.tag
    for k, v in stl_container_dict.items():
        if re.search(k, typename):
            return v(val)
    return None

def get_string_length(value):
    # Make sure &string works, too.
    valtype = value.type
    if valtype.code == gdb.TYPE_CODE_REF:
        valtype = valtype.target ()

    # Calculate the length of the string so that to_string returns
    # the string according to length, not according to first null
    # encountered.
    ptr = value['_M_dataplus']['_M_p']
    realtype = valtype.unqualified().strip_typedefs()
    reptype = gdb.lookup_type (str (realtype) + '::_Rep').pointer ()
    rep = (ptr.cast(reptype) - 1).dereference()
    return int(rep['_M_length']), int(rep['_M_capacity'])

get_string_bytes = get_string_length

def get_vec_size(val):
    start = val['_M_impl']['_M_start']
    finish = val['_M_impl']['_M_finish']
    end = val['_M_impl']['_M_end_of_storage']
    return (int(finish - start), int(end - start))

def get_vec_bytes(val):
    size, capacity = get_vec_size(val)
    elem_type = val.type.template_argument(0)
    return size * elem_type.sizeof, capacity * elem_type.sizeof

def get_map_size(value):
    return int(value['_M_t']['_M_impl']['_M_node_count'])

def get_set_size(value):
    return int(value['_M_t']['_M_impl']['_M_node_count'])

def get_set_nodetype(value):
    keytype = value.type.template_argument(0)
    nodetype = gdb.lookup_type('std::_Rb_tree_node< %s >' % keytype).pointer()
    return nodetype

def get_set_keytype(value):
    return value.type.template_argument(0)

def get_podset_bytes(value):
    return get_set_size(value) * get_set_nodetype(value).sizeof

def get_map_keytype(value):
    return value.type.template_argument(0).const()

def get_map_valtype(value):
    return value.type.template_argument(1)

def get_map_nodetype(value):
    keytype = get_map_keytype(value)
    valuetype = get_map_valtype(value)
    return gdb.lookup_type('std::_Rb_tree_node< std::pair< %s, %s > >' % (keytype, valuetype)).pointer()

class IteratorMeta(type):
    name_pattern = re.compile(r'Std(\w+)Iterator')

    def __new__(meta, name, bases, dct):
        print(name)
        stl_short_name = re.search(IteratorMeta.name_pattern, name).group(1).lower()
        cls = super(IteratorMeta, meta).__new__(meta, name, bases, dct)
        stl_iter_dict[re.compile('^std::%s<.*>$' % (stl_short_name))] = cls
        return cls

class ContainerMeta(type):
    name_pattern = re.compile(r'^Std(\w+)$')

    def __new__(meta, name, bases, dct):
        stl_short_name = re.search(ContainerMeta.name_pattern, name).group(1).lower()
        cls = super(ContainerMeta, meta).__new__(meta, name, bases, dct)
        stl_container_dict[re.compile('^std::%s<.*>$' % (stl_short_name))] = cls
        return cls

if sys.version[0] == '2':
    class StdBase(object):
        __metaclass__ = ContainerMeta
else:
    class StdBase(object, metaclass = ContainerMeta):
        pass

class StdBaseIterator(object):
    __metaclass__ = IteratorMeta

    def __add__(self, n):
        if not isinstance(n, int) or n < 0:
            raise RuntimeError('iterator can only be added to a non-negative int')

        x = self
        for i in range(n):
            x = next(self)
        return x

class StdVectorIterator(StdBaseIterator):
    def __init__ (self, vector, index = 0):
        self.vector = vector
        self.index = index
        self.pointer = self.vector.start + index

    def __next__(self):
        if self.index >= len(self.vector.size):
            raise StopIteration
        self.index += 1
        self.pointer += 1
        return self

    def __add__(self, n):
        return StdVectorIterator(self.vector, self.index + n)

    def __str__(self):
        return str(self.pointer.dereference())

class StdVectorReverseIterator(StdBaseIterator):
    def __init__ (self, vector, index = 0):
        self.vector = vector
        self.index = index
        self.pointer = self.vector.finish - index - 1

    def base(self):
        return StdVectorIterator(self.vector, self.vector.size - self.index - 1)

    def __add__(self, n):
        return StdVectorReverseIterator(self.vector, self.index - n)

    def __str__(self):
        return str(self.val.dereference())

class StdVector(StdBase):
    def __init__ (self, val):
        self.start = val['_M_impl']['_M_start']
        self.finish = val['_M_impl']['_M_finish']
        self.count = int(self.finish - self.start)

    def size(self):
        return self.count

    def begin(self):
        return StdVectorIterator(self.start)

    def end(self):
        return StdVectorIterator(self.finish)

    def rbegin(self):
        return StdVectorReverseIterator(self.finish - 1)

    def rend(self):
        return StdVectorReverseIterator(self.start - 1)

    def __iter__(self):
        first = self.start
        while first != self.finish:
            elt = first.dereference()
            first += 1
            yield elt

class StdRbtreeIterator(StdBaseIterator):
    def __init__(self, container, count):
        assert count <= len(container)
        self.container = container
        self.count = 0
        self.node = container.first_node
        self.forward(count)

    def forward(self, n):
        node = self.node
        n = min(n, len(self.container) - n)
        for i in range(n):
            if node.dereference()['_M_right']:
                node = node.dereference()['_M_right']
                while node.dereference()['_M_left']:
                    node = node.dereference()['_M_left']
            else:
                parent = node.dereference()['_M_parent']
                while node == parent.dereference()['_M_right']:
                    node = parent
                    parent = parent.dereference()['_M_parent']
                if node.dereference()['_M_right'] != parent:
                    node = parent
        self.count += n
        self.node = node

    def __next__(self):
        if self.count >= len(self.container):
            raise StopIteration
        self.forward(1)
        return self

    def __eq__(self, other):
        return self.count == other.count and self.container == other.container

    next = __next__

class StdRbtree(StdBase):
    def __init__(self, val):
        self.first_node = val['_M_t']['_M_impl']['_M_header']['_M_left']
        self.val = val
        self.node_count = int(val['_M_t']['_M_impl']['_M_node_count'])
        self.node_type = None

    def __iter__(self):
        x = self.begin()
        for i in range(self.node_count):
            yield x
            x = next(x)

    def __len__(self):
        return self.node_count

    def __str__(self):
        return str(self.val)

    def size(self):
        return self.node_count

    def begin(self):
        return self.iter_class(self, 0)

    def end(self):
        return self.iter_class(self, self.size())

class StdSetIterator(StdRbtreeIterator):
    def __init__(self, container, count=0):
        super(self.__class__, self).__init__(container, count)

    def __str__(self):
        x = self.node.cast(self.container.nodetype).dereference()
        try:
            value = x['_M_value_field']
        except RuntimeError:
            value = x['_M_storage']['_M_storage'].address.cast(
                    self.container.keytype.pointer()).dereference()
        return str(value)

class StdSet(StdRbtree):
    iter_class = StdSetIterator
    def __init__(self, val):
        super(self.__class__, self).__init__(val)
        self.nodetype = get_set_nodetype(val)
        self.keytype = get_set_keytype(val)

class StdMapIterator(StdRbtreeIterator):
    def __init__(self, container, count):
        super(self.__class__, self).__init__(container, count)

    def forward(self, n):
        super(self.__class__, self).forward(n)
        x = self.node.cast(self.container.nodetype).dereference()
        try:
            self.value = x['_M_value_field']
        except gdb.error:
            self.value = x['_M_storage']['_M_storage'].address.cast(
                    self.container.valtype).dereference()

    def __str__(self):
        if self.count < len(self.container):
            return 'pair<%s, %s>' % (self.first, self.second)
        elif self.count >= len(self.container):
            return 'pair<End_Of_map>'
        else:
            raise ValueError('out of range')

    @property
    def first(self):
        return self.value['first']

    @property
    def second(self):
        return self.value['second']

class StdMap(StdRbtree):
    iter_class = StdMapIterator
    def __init__(self, val):
        super(self.__class__, self).__init__(val)
        self.nodetype = get_map_nodetype(val)
        self.valtype = self.nodetype.target().template_argument(0).pointer()

    def __getitem__(self, item):
        for x in self:
            if str(x.first) == str(item):
                return x.second
        raise KeyError('key {} not found'.format(item))

class StdListIterator:
    '''
    The iterator of the STL list. The value can be fetched from list.begin(),
    list.end() etc.
    '''
    def __init__(self, val):
        self.typename = val.type.name
        self.nodetype = StdListIterator.get_nodetype(val)
        self.node = self.val['_M_node']

    def __eq__(self, other):
        return self.node == other.node

    def __str__(self):
        return str(self.node.cast(self.nodetype).dereference()['_M_data'])

    def forward(self):
        self.node = self.node['_M_next']

    @staticmethod
    def get_nodetype(val):
        typename = val.type.name
        itype = val.type.template_argument(0)

        # If the inferior program is compiled with -D_GLIBCXX_DEBUG
        # some of the internal implementation details change.
        if typename == "std::_List_iterator" or typename == "std::_List_const_iterator":
            return gdb.lookup_type('std::_List_node<%s>' % itype).pointer()
        elif typename == "std::__norm::_List_iterator" or typename == "std::__norm::_List_const_iterator":
            return gdb.lookup_type('std::__norm::_List_node<%s>' % itype).pointer()
        else:
            raise ValueError("Cannot cast list node for list iterator printer.")

class StdList(object):
    '''
    The python representation of the STL list.
    '''
    def __init__(self, val, head):
        self.val = val
        self.nodetype = StdList.get_nodetype(self.val)
        head = self.val['_M_impl']['_M_node']
        self.base = head['_M_next']
        self.head = head.address

    def __iter__(self):
        return self

    def __next__(self):
        if self.base == self.head:
            raise StopIteration
        elt = self.base.cast(self.nodetype).dereference()
        self.base = elt['_M_next']
        return elt['_M_data']

    @staticmethod
    def get_nodetype(stl_list):
        typename = stl_list.type.name
        itype = stl_list.type.template_argument(0)
        # If the inferior program is compiled with -D_GLIBCXX_DEBUG
        # some of the internal implementation details change.
        if typename == "std::list":
            return gdb.lookup_type('std::_List_node<%s>' % itype).pointer()
        elif typename == "std::__debug::list":
            return gdb.lookup_type('std::__norm::_List_node<%s>' % itype).pointer()
        else:
            raise ValueError('{0} not a list type'.format(typename))

class StdString(object):
    pass

class PrintStl(gdb.Command):
    '''
    Print STL expression
    Usage: pstl
    '''
    def __init__(self):
        super(self.__class__, self).__init__("pstl", gdb.COMMAND_NONE)
        self.dont_repeat()

    def invoke(self, args, from_tty):
        if len(args) < 1:
            print('Usage: pstl <expression>')
            return

        params = re.split(r'(\.|(?: *\+ *)|\[\w+\]|(?:\w+\(\)))', args.strip(". '"))
        stl_val = gdb.parse_and_eval(params[0])
        for k, v in stl_container_dict.items():
            if re.search(k, stl_val.type.tag):
                val = v(stl_val)
                i = 0
                params = [x for x in params[1:] if x]
                while i < len(params):
                    op = params[i].strip()
                    if op:
                        if op in ('.', '+'):
                            val = eval('val{0}{1}'.format(op, params[i+1]))
                            i += 1
                        else:
                            val = eval('val%s' % params[i])
                    i += 1
                print(val)
                break
        else:
            print('unknown container type: %s' % stl_val.type.tag)

class PrintKey(gdb.Command):
    '''
    Usage: pkey <map> <key>
    Print the key of a map.
    '''
    def __init__(self):
        super(self.__class__, self).__init__("pkey", gdb.COMMAND_NONE)
        self.dont_repeat()

    def invoke(self, args, from_tty):
        all_args = args.split()
        if len(all_args) < 2:
            raise ValueError('incorrect arguments')

        stl_map = all_args[0]
        keys = set(all_args[1:])
        for x in StdMapIterator(gdb.parse_and_eval(stl_map)):
            if str(x['first']) in keys:
                print(x['second'])


PrintStl()
PrintKey()

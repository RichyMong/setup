import gdb
from mystd.v6 import stl_util

class PrintRange(gdb.Command):
    '''
    Print a range of STL iterator. The usage is like most of the STL
    algorithms. The caller should ensure the two iterators point to
    the same underlying container.
    Usage: prange <start> <end>
    '''
    def __init__(self):
        super(self.__class__, self).__init__(
            "prange", gdb.COMMAND_USER, gdb.COMPLETE_EXPRESSION)

    def invoke(self, args, from_tty):
        argv = gdb.string_to_argv(args)
        if len(argv) != 2:
            raise gdb.GdbError('incorrect arguments')

        start = stl_util.StdListIterator(gdb.parse_and_eval(argv[0]))
        end = stl_util.StdLIstIterator(gdb.parse_and_eval(argv[1]))
        while start != end:
            print(start)
            start.forward()

PrintRange()

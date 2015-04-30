module util.newaa;

import util.murmurhash;
import std.traits;
import std.stdio : writeln;
import core.stdc.stdlib;
import core.exception;
import core.memory : GC;
import core.stdc.string;

enum DefaultHashTableSize = 1019;
enum defaultBucketSize = 5;

auto newAA(size_t hashTableSize = DefaultHashTableSize, T...)(T args)
{
    return NewAA!(T[1], T[0], hashTableSize)(args);
}



void GCaddRangeNewAA(alias values, alias keys, VT, KT)(size_t size)
{
    static if ((isArray!VT || isAggregateType!VT) && (isArray!KT || isAggregateType!KT))
    {
        GC.addRange(keys, size * (KT.sizeof + VT.sizeof));
    }
    else static if (isArray!VT || isAggregateType!VT)
    {
        GC.addRange(values, size * VT.sizeof);
    }
    else static if (isArray!KT || isAggregateType!KT)
    {
        GC.addRange(keys, size * KT.sizeof);
    }
}

struct NewAA(VT, KT, size_t hashTableSize = DefaultHashTableSize)
{
    struct List
    {
        KT* keys = null;
        VT* values = null;

        int count = 0;
        int size = 0;

        void addItem(VT value, KT key)
        {
            size += defaultBucketSize;
            auto realSize = size + 1;
            keys = cast(KT*)core.stdc.stdlib.realloc(keys, realSize * (KT.sizeof));
            values = cast(VT*)core.stdc.stdlib.realloc(values, realSize * (VT.sizeof));

            static if (isArray!VT || isAggregateType!VT || isArray!KT || isAggregateType!KT)
            {
                GCaddRangeNewAA!(values, keys, VT, KT)(realSize);
            }

            *(keys + count) = key;
            *(values + count) = value;
            ++count;
        }       

        void addSentinel(KT key)
        {
            *(keys + count) = key;
        }
        
    }
    
    private size_t _itemsCount;
    
    //alias toBuiltinAA this;
    
    bool canCleanup = true;
    
    List* hashTable = null;
    
    @property length()
    {
        return _itemsCount;
    }
    
    this(this)
    {
        canCleanup = false;
    }

    
    this(T...)(T args) if (args.length > 1)
    {
        KT key;
        
        auto p = core.stdc.stdlib.calloc(hashTableSize, List.sizeof);
        if (!p)
        {
            throw new OutOfMemoryError();
        }
        
        hashTable = (cast(List *)p);
        
        static if (is(T[0] == KT) && is(T[1] == VT))
        {
            VT* values = void;
            ptrdiff_t i = getKeyIndex(args[0]);
            key = args[0];
            List* list = hashTable + i;
            auto keys = cast(KT*)core.stdc.stdlib.malloc(defaultBucketSize * (KT.sizeof + VT.sizeof));
            list.keys = keys;
            values = cast(VT*)(list.keys + defaultBucketSize);
            static if (isArray!VT || isAggregateType!VT || isArray!KT || isAggregateType!KT)
            {
                GCaddRangeNewAA!(values, keys, VT, KT)(defaultBucketSize);
            }
            *(list.keys) = key;
            *(values) = args[1];
            list.size = defaultBucketSize;
            list.count = 1;
            ++_itemsCount;
        }
        
        foreach (index, arg; args[2 .. $])
        {
            if (index % 2 == 0)
            {
                static if (is(T[2+index] == KT))
                {
                    key = arg;
                }
            }
            else
            {
                static if (is(T[2+index] == VT))
                {
                    opIndexAssign(arg, key);
                }
            }
        }
    }
    
    ~this()
    {
        if (canCleanup)
        {
            foreach (list; hashTable[0 .. hashTableSize])
            {
                core.stdc.stdlib.free(list.keys);
            }
            core.stdc.stdlib.free(hashTable);
        }
    }

    hash_t getKeyHash(T)(T key)
    {
        static if (isIntegral!T)
        {
            import util.fasthash;
            return key;//FarmHash64((cast(ubyte*)&key)[0 .. T.sizeof]);
        }
        else
        {
            return MurmurHash64(key);
        }
    }
    
    size_t getKeyIndex(T)(T key)
    {
        return getKeyHash(key) % hashTableSize;
    }

    VT* opBinaryRight(string op)(KT key) if (op == "in")
    {
        ptrdiff_t keyIndex = getKeyIndex(key);
        auto list = hashTable + keyIndex;

        return findKey(key, list);

    }

    void opIndexAssign(VT value, KT key)
    {
        if (hashTable is null)
        {
            auto p = core.stdc.stdlib.calloc(hashTableSize, List.sizeof);
            if (!p)
            {
                throw new OutOfMemoryError();
            }
            
            hashTable = (cast(List *)p);
        }
        size_t keyIndex = getKeyIndex(key);
        auto list = hashTable + keyIndex;

        if (list.count == list.size) {
            list.addItem(value, key);
            return;
        }

        list.addSentinel(key);

        KT* haystack = list.keys;

        int off = 0;
        
        while (*haystack++ != key)
        {
            ++off;
        }

        *(list.values + off) = value;

        if (off == list.count) {
            ++list.count;
        }
    }

    /*KT* findKey(KT key, List* list)
     {
     KT* haystack = list.keys;
     KT* end = list.lastKey + 1;
     while (haystack != end )
     {
     if (*haystack == key)
     {
     return haystack;
     }
     ++haystack;
     }

     return null;
     }*/

    int findOffset(KT key, List* list)
    {
        KT* haystack = list.keys;
        typeof(return) offset = 0;
        while (offset < list.count)
        {
            if (*(haystack + offset) == key)
            {
                return offset;
            }
            ++offset;
        }
        
        return -1;
    }
    
    VT opIndex(KT key)
    {
        auto keyIndex = getKeyIndex(key);
        auto list = hashTable + keyIndex;

        int offset = 0;

        while (offset != list.count)
        {
            if (*(list.keys + offset) == key)
            {
                return *(list.values + offset);
            }
            ++offset;
        }
        return VT.init;
    }

    /**
     * not implemented yet
     */
    bool remove(KT key)
    {
        ptrdiff_t keyIndex = getKeyIndex(key);
        auto list = hashTable + keyIndex;
        return false;
    }
    
}

